/**
 * HTTP, normalization, and extractor plumbing for the web tools. Imports no Pi
 * APIs so tests can exercise it directly; every request is bounded by a deadline
 * and a body byte ceiling, and every returned field is truncated.
 */

import { spawn } from "node:child_process";

const SEARCH_TIMEOUT_MS = 15_000;
const FETCH_TIMEOUT_MS = 20_000;
const EXTRACT_TIMEOUT_MS = 5_000;
const SEARCH_MAX_RESPONSE_BYTES = 1024 * 1024;
const FETCH_MAX_RESPONSE_BYTES = 2 * 1024 * 1024;
const EXTRACT_MAX_OUTPUT_BYTES = 4 * 1024 * 1024;
const EXTRACT_MAX_ERROR_BYTES = 8 * 1024;
const MAX_REDIRECTS = 5;
const MAX_URL_CHARS = 4000;
const MAX_CONTENT_TYPE_CHARS = 200;
const MAX_QUERY_CHARS = 2000;
const SEARCH_RESULTS = 5;
const FETCH_CHARS = 12_000;
const MAX_RESULT_TITLE_CHARS = 300;
const MAX_RESULT_URL_CHARS = 2000;
const MAX_RESULT_SNIPPET_CHARS = 500;
const MAX_RESULT_SOURCES = 5;
const MAX_RESULTS_SCANNED = 100;
const MAX_ENGINES = 10;
const MAX_WARNINGS = 10;

export const MAX_CONCURRENT_OPERATIONS = 4;

/** Deployment bindings supplied by the extension bootstrap. */
export type WebConfig = {
  /** Search endpoint of the deployed search service. */
  searchEndpoint: string;
  /** Python interpreter that provides trafilatura. */
  python: string;
  /** Path to extract.py. */
  extractScript: string;
};

export type SearchInput = { query: string };
export type FetchInput = { url: string };

export type SearchResult = {
  title: string;
  url: string;
  snippet: string;
  sources: string[];
  score: number | null;
};

export type EngineTiming = {
  name: string;
  status: string;
  resultCount: number;
  timeMs: number;
  httpStatus: number | null;
  error: string | null;
};

export type SearchOutput = {
  query: string;
  provider: string;
  results: SearchResult[];
  engines: EngineTiming[];
  warnings: string[];
  returned: number;
  omitted: number;
};

export type FetchOutput = {
  requestedUrl: string;
  finalUrl: string;
  contentType: string;
  extraction: "markdown" | "text" | "trafilatura";
  content: string;
  contentChars: number;
  truncated: boolean;
  redirects: number;
};

export type OperationSlots = {
  /** Reserve one of the fixed operation slots; throws when all are in use. */
  acquire(tool: string): () => void;
};

export function createOperationSlots(): OperationSlots {
  const max = MAX_CONCURRENT_OPERATIONS;
  let active = 0;
  return {
    acquire(tool) {
      if (active >= max) {
        throw new Error(`${tool} rejected: ${max} web operations are already running`);
      }
      active += 1;
      let released = false;
      return () => {
        if (released) return;
        released = true;
        active -= 1;
      };
    },
  };
}

/**
 * Run `task` under a deadline that also follows `parent`. Aborting only aborts the
 * signal the task observes, and the call settles after the task settles, so the
 * extractor is killed and reaped before the caller reports and releases its slot.
 */
export async function runWithDeadline<T>(
  timeoutMs: number,
  parent: AbortSignal | undefined,
  label: string,
  task: (signal: AbortSignal) => Promise<T>,
): Promise<T> {
  const controller = new AbortController();
  let timedOut = false;
  const abortMessage = () => (timedOut ? `${label} timed out after ${timeoutMs} ms` : `${label} was cancelled`);
  const timer = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);
  const cancel = () => controller.abort();
  if (parent?.aborted) controller.abort();
  else parent?.addEventListener("abort", cancel, { once: true });
  try {
    const result = await task(controller.signal);
    if (controller.signal.aborted) throw new Error(abortMessage());
    return result;
  } catch (error) {
    if (controller.signal.aborted) throw new Error(abortMessage());
    throw error;
  } finally {
    clearTimeout(timer);
    parent?.removeEventListener("abort", cancel);
  }
}

/** Validate an explicit http(s) URL and reject embedded credentials. */
function validateHttpUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(`invalid URL: ${raw}`);
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error(`unsupported URL scheme "${url.protocol}" (only http and https are allowed)`);
  }
  if (url.username || url.password) {
    throw new Error("URLs with embedded credentials are not allowed");
  }
  if (url.href.length > MAX_URL_CHARS) {
    throw new Error(`URL exceeds ${MAX_URL_CHARS} characters`);
  }
  return url;
}

/** Truncate text without splitting a surrogate pair. */
function truncateText(text: string, maxChars: number): { text: string; truncated: boolean; totalChars: number } {
  if (text.length <= maxChars) {
    return { text, truncated: false, totalChars: text.length };
  }
  let end = maxChars;
  const last = text.charCodeAt(end - 1);
  if (last >= 0xd800 && last <= 0xdbff) end -= 1;
  return { text: text.slice(0, end), truncated: true, totalChars: text.length };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function mediaType(contentType: string | null): string {
  return (contentType ?? "").split(";")[0]?.trim().toLowerCase() ?? "";
}

function decodeBody(body: Uint8Array, contentType: string | null): string {
  const charset = httpCharset(contentType);
  try {
    return new TextDecoder(charset ?? "utf-8").decode(body);
  } catch {
    return new TextDecoder("utf-8").decode(body);
  }
}

function httpCharset(contentType: string | null): string | null {
  return /charset\s*=\s*"?([^";\s]+)/i.exec(contentType ?? "")?.[1] ?? null;
}

/** Decode only with an authoritative HTTP charset; otherwise keep the original bytes. */
function decodeHtml(body: Uint8Array, contentType: string | null): string | Uint8Array {
  const charset = httpCharset(contentType);
  if (!charset) return body;
  try {
    return new TextDecoder(charset).decode(body);
  } catch {
    return body;
  }
}

async function readBoundedBody(response: Response, limitBytes: number): Promise<Uint8Array> {
  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > limitBytes) {
    await response.body?.cancel().catch(() => {});
    throw new Error(`response body exceeds ${limitBytes} bytes (content-length ${declared})`);
  }
  if (!response.body) return new Uint8Array();
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limitBytes) {
        await reader.cancel().catch(() => {});
        throw new Error(`response body exceeds ${limitBytes} bytes`);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const body = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return body;
}

type RawResponse = {
  response: Response;
  finalUrl: URL;
  redirects: number;
};

const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const TEXTUAL_JSON = /^application\/(?:[\w.-]+\+)?json$/;

async function requestFollowingRedirects(start: URL, accept: string, signal: AbortSignal): Promise<RawResponse> {
  let current = start;
  for (let redirects = 0; ; redirects += 1) {
    const response = await fetch(current, {
      method: "GET",
      redirect: "manual",
      headers: { accept },
      signal,
    });
    if (!REDIRECT_STATUSES.has(response.status)) {
      return { response, finalUrl: current, redirects };
    }
    const location = response.headers.get("location");
    await response.body?.cancel().catch(() => {});
    if (!location) {
      throw new Error(`HTTP ${response.status} redirect from ${current.href} has no location header`);
    }
    if (redirects >= MAX_REDIRECTS) {
      throw new Error(`too many redirects (limit ${MAX_REDIRECTS}) starting at ${start.href}`);
    }
    current = validateHttpUrl(new URL(location, current).href);
  }
}

function httpError(response: Response, url: URL): Error {
  return new Error(`HTTP ${response.status}${response.statusText ? ` ${response.statusText}` : ""} for ${url.href}`);
}

function clamp(value: string, maxChars: number): string {
  return truncateText(value.trim(), maxChars).text;
}

function normalizeEngineTimings(value: unknown): EngineTiming[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, MAX_ENGINES).flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const timing: EngineTiming = {
      name: clamp(typeof entry.name === "string" ? entry.name : "unknown", 80),
      status: typeof entry.status === "string" ? clamp(entry.status, 40) : "ok",
      resultCount: typeof entry.resultCount === "number" && Number.isInteger(entry.resultCount) && entry.resultCount >= 0 ? entry.resultCount : 0,
      timeMs: typeof entry.time === "number" && Number.isFinite(entry.time) && entry.time >= 0 ? entry.time : 0,
      httpStatus: typeof entry.httpStatus === "number" && Number.isInteger(entry.httpStatus) && entry.httpStatus >= 100 && entry.httpStatus <= 599 ? entry.httpStatus : null,
      error: typeof entry.errorReason === "string" ? clamp(entry.errorReason, 200) : null,
    };
    return [timing];
  });
}

function normalizeResults(raw: unknown[]): { results: SearchResult[]; invalid: number } {
  const results: SearchResult[] = [];
  let invalid = 0;
  for (const item of raw.slice(0, MAX_RESULTS_SCANNED)) {
    if (!isRecord(item) || typeof item.title !== "string" || typeof item.url !== "string" || !item.title.trim()) {
      invalid += 1;
      continue;
    }
    let url: URL;
    try {
      url = validateHttpUrl(item.url);
    } catch {
      invalid += 1;
      continue;
    }
    if (url.href.length > MAX_RESULT_URL_CHARS) {
      invalid += 1;
      continue;
    }
    results.push({
      title: clamp(item.title, MAX_RESULT_TITLE_CHARS),
      url: url.href,
      snippet: typeof item.snippet === "string" ? clamp(item.snippet, MAX_RESULT_SNIPPET_CHARS) : "",
      sources: Array.isArray(item.sources)
        ? item.sources
            .filter((source): source is string => typeof source === "string")
            .slice(0, MAX_RESULT_SOURCES)
            .map((source) => clamp(source, 80))
        : [],
      score: typeof item.score === "number" && Number.isFinite(item.score) ? item.score : null,
    });
  }
  return { results, invalid };
}

function searchWarnings(engines: EngineTiming[], invalid: number, rawCount: number): string[] {
  const warnings: string[] = [];
  for (const engine of engines) {
    if (engine.status === "ok") continue;
    const detail = engine.error ? `: ${engine.error}` : "";
    warnings.push(clamp(`${engine.name} ${engine.status}${detail}`, 300));
    if (warnings.length >= MAX_WARNINGS) break;
  }
  if (invalid > 0 && warnings.length < MAX_WARNINGS) {
    warnings.push(`Skipped ${invalid} malformed, non-http, or overlong search results`);
  }
  if (rawCount === 0 && engines.length === 0) {
    warnings.push("Search provider returned no results and no engine timings");
  }
  return warnings;
}

/** Run one bounded search against the deployed search endpoint. */
export async function webSearch(config: WebConfig, input: SearchInput, signal?: AbortSignal): Promise<SearchOutput> {
  const query = typeof input.query === "string" ? input.query.trim() : "";
  if (!query) throw new Error("query must not be empty");
  if (query.length > MAX_QUERY_CHARS) throw new Error(`query exceeds ${MAX_QUERY_CHARS} characters`);

  const url = validateHttpUrl(config.searchEndpoint);
  url.searchParams.set("q", query);
  url.searchParams.set("type", "web");

  return runWithDeadline(SEARCH_TIMEOUT_MS, signal, "web_search", async (deadline) => {
    const { response, finalUrl } = await requestFollowingRedirects(url, "application/json", deadline);
    if (!response.ok) {
      await response.body?.cancel().catch(() => {});
      throw httpError(response, finalUrl);
    }
    const contentType = response.headers.get("content-type");
    if (!mediaType(contentType).includes("json")) {
      await response.body?.cancel().catch(() => {});
      throw new Error(`search endpoint returned unsupported content type "${contentType ?? "none"}"`);
    }
    const body = await readBoundedBody(response, SEARCH_MAX_RESPONSE_BYTES);
    let data: unknown;
    try {
      data = JSON.parse(decodeBody(body, contentType));
    } catch {
      throw new Error(`search endpoint ${finalUrl.href} returned invalid JSON`);
    }
    if (!isRecord(data) || !Array.isArray(data.results)) {
      throw new Error(`search endpoint ${finalUrl.href} returned an unexpected response shape`);
    }

    const engines = normalizeEngineTimings(data.engineTimings);
    const { results, invalid } = normalizeResults(data.results);
    const warnings = searchWarnings(engines, invalid, data.results.length);
    if (results.length === 0 && engines.length > 0 && engines.every((engine) => engine.status !== "ok")) {
      throw new Error(`search failed: every engine reported an error (${warnings.join("; ")})`);
    }
    return {
      query,
      provider: truncateText(finalUrl.host, 200).text,
      results: results.slice(0, SEARCH_RESULTS),
      engines,
      warnings,
      returned: Math.min(results.length, SEARCH_RESULTS),
      omitted: Math.max(0, data.results.length - Math.min(results.length, SEARCH_RESULTS)),
    };
  });
}

/** Run extract.py over HTML, bounded by a five-second ceiling and the caller's signal. */
export async function runExtractor(
  config: WebConfig,
  html: string | Uint8Array,
  finalUrl: string,
  signal: AbortSignal,
): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    let settled = false;
    let failure: Error | undefined;
    const child = spawn(config.python, [config.extractScript, finalUrl], { stdio: ["pipe", "pipe", "pipe"] });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    let stdoutBytes = 0;
    let stderrBytes = 0;
    const cleanup = () => {
      clearTimeout(timer);
      signal.removeEventListener("abort", onAbort);
    };
    // A failure kills the child and settles only from its close event, so the
    // extractor is reaped before the caller releases its operation slot.
    const fail = (error: Error) => {
      if (failure || settled) return;
      failure = error;
      child.kill("SIGKILL");
    };
    const onAbort = () => fail(new Error("content extraction was cancelled"));
    const timer = setTimeout(() => fail(new Error(`content extraction timed out after ${EXTRACT_TIMEOUT_MS} ms`)), EXTRACT_TIMEOUT_MS);
    if (signal.aborted) onAbort();
    else signal.addEventListener("abort", onAbort, { once: true });

    child.on("error", (error) => fail(new Error(`could not run ${config.python}: ${error.message}`)));
    child.stdout.on("data", (chunk: Buffer) => {
      stdoutBytes += chunk.length;
      if (stdoutBytes > EXTRACT_MAX_OUTPUT_BYTES) {
        fail(new Error(`extraction output exceeded ${EXTRACT_MAX_OUTPUT_BYTES} bytes`));
        return;
      }
      stdout.push(chunk);
    });
    child.stderr.on("data", (chunk: Buffer) => {
      if (stderrBytes >= EXTRACT_MAX_ERROR_BYTES) return;
      const kept = chunk.subarray(0, EXTRACT_MAX_ERROR_BYTES - stderrBytes);
      stderrBytes += kept.length;
      stderr.push(kept);
    });
    child.on("close", (code, signalName) => {
      cleanup();
      if (settled) return;
      settled = true;
      if (failure) {
        reject(failure);
        return;
      }
      if (code !== 0) {
        const detail = Buffer.concat(stderr).toString("utf8").trim().slice(0, 500);
        reject(new Error(`content extraction failed (${code === null ? signalName : `exit ${code}`})${detail ? `: ${detail}` : ""}`));
        return;
      }
      const text = Buffer.concat(stdout).toString("utf8").trim();
      if (!text) {
        reject(new Error("content extraction produced no text"));
        return;
      }
      resolve(text);
    });
    child.stdin.on("error", () => {});
    child.stdin.end(html);
  });
}

/** Fetch one explicit URL and return bounded Markdown, text, or extracted HTML. */
export async function webFetch(config: WebConfig, input: FetchInput, signal?: AbortSignal): Promise<FetchOutput> {
  const requested = validateHttpUrl(input.url);

  return runWithDeadline(FETCH_TIMEOUT_MS, signal, "web_fetch", async (deadline) => {
    const accept = "text/markdown, text/html;q=0.8, text/plain;q=0.5, application/json;q=0.5";
    const { response, finalUrl, redirects } = await requestFollowingRedirects(requested, accept, deadline);
    if (!response.ok) {
      await response.body?.cancel().catch(() => {});
      throw httpError(response, finalUrl);
    }
    const contentType = response.headers.get("content-type");
    const type = mediaType(contentType);
    const isHtml = type === "text/html" || type === "application/xhtml+xml";
    const isMarkdown = type === "text/markdown";
    const isText = !isHtml && !isMarkdown && (type.startsWith("text/") || TEXTUAL_JSON.test(type));
    if (!isHtml && !isMarkdown && !isText) {
      await response.body?.cancel().catch(() => {});
      const safeType = truncateText(contentType ?? "none", MAX_CONTENT_TYPE_CHARS).text;
      throw new Error(
        `unsupported content type "${safeType}" from ${finalUrl.href}; only HTML, Markdown, plain text, and JSON are supported`,
      );
    }

    const body = await readBoundedBody(response, FETCH_MAX_RESPONSE_BYTES);
    let method: FetchOutput["extraction"];
    let text: string;
    if (isHtml) {
      method = "trafilatura";
      text = await runExtractor(config, decodeHtml(body, contentType), finalUrl.href, deadline);
    } else {
      method = isMarkdown ? "markdown" : "text";
      text = decodeBody(body, contentType).trim();
    }

    const clamped = truncateText(text, FETCH_CHARS);
    return {
      requestedUrl: requested.href,
      finalUrl: finalUrl.href,
      contentType: truncateText(contentType ?? "none", MAX_CONTENT_TYPE_CHARS).text,
      extraction: method,
      content: clamped.text,
      contentChars: clamped.totalChars,
      truncated: clamped.truncated,
      redirects,
    };
  });
}
