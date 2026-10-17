import { afterAll, afterEach, describe, expect, test } from "bun:test";
import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { MAX_CONCURRENT_OPERATIONS, runWithDeadline, webFetch, webSearch, type WebConfig } from "./core.ts";
import { registerWebTools } from "./extension.ts";

const extractScript = fileURLToPath(new URL("./extract.py", import.meta.url));
// Test-only binding: extraction tests skip when PI_WEB_PYTHON is unset.
const python = process.env.PI_WEB_PYTHON;
const fixtures = mkdtempSync(join(tmpdir(), "pi-web-test-"));

afterAll(() => rmSync(fixtures, { recursive: true, force: true }));

const servers: Array<{ stop(force?: boolean): void }> = [];
function serve(handler: (request: Request) => Response | Promise<Response>): string {
  const server = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: handler });
  servers.push(server);
  return server.url.origin;
}
afterEach(() => {
  for (const server of servers.splice(0)) server.stop(true);
});

function config(origin: string, overrides: Partial<WebConfig> = {}): WebConfig {
  return { searchEndpoint: `${origin}/api/search`, python: python ?? join(fixtures, "absent-python"), extractScript, ...overrides };
}
function respond(body: string, contentType: string): Response {
  return new Response(body, { headers: { "content-type": contentType } });
}
function redirect(location: string, status = 302): Response {
  return new Response(null, { status, headers: { location } });
}
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
const pathOf = (request: Request) => new URL(request.url).pathname;
async function waitForFile(file: string): Promise<void> {
  for (let attempt = 0; attempt < 250; attempt += 1) {
    if (existsSync(file)) return;
    await Bun.sleep(20);
  }
  throw new Error(`${file} was not created`);
}

const searchResponse = {
  engineTimings: [{ name: "Brave", time: 531, resultCount: 0, status: "rate_limited", errorReason: "upstream HTTP 429", httpStatus: 429 }, { name: "DuckDuckGo", time: 578, resultCount: 3, status: "ok" }],
  results: [
    { title: "Nix flakes", url: "https://wiki.nixos.org/wiki/Flakes", snippet: "Flakes are a feature.", score: 10, sources: ["DuckDuckGo"] },
    { title: "Bad scheme", url: "ftp://example.com/x" },
    { title: "Overlong", url: `https://example.com/${"a".repeat(2500)}` },
    { snippet: "no title or url" },
  ],
};

describe("web_search", () => {
  test("normalizes results, reports partial engine failures, and rejects invalid data", async () => {
    let query: URLSearchParams | undefined;
    const origin = serve((request) => {
      query = new URL(request.url).searchParams;
      return json(searchResponse);
    });

    const output = await webSearch(config(origin), { query: " nix flakes " });
    expect([query?.get("q"), query?.get("type")]).toEqual(["nix flakes", "web"]);
    expect(output).toMatchObject({ query: "nix flakes", provider: new URL(origin).host, returned: 1, omitted: 3 });
    expect(output.results).toEqual([
      { title: "Nix flakes", url: "https://wiki.nixos.org/wiki/Flakes", snippet: "Flakes are a feature.", sources: ["DuckDuckGo"], score: 10 },
    ]);
    expect(output.engines[0]).toMatchObject({ name: "Brave", status: "rate_limited", httpStatus: 429 });
    expect(output.warnings.join(" ")).toMatch(/Brave rate_limited.*Skipped 3 malformed/);

    const empty = serve(() => json({ engineTimings: [{ name: "DuckDuckGo", status: "ok", resultCount: 0, time: 5 }], results: [] }));
    expect(await webSearch(config(empty), { query: "nothing" })).toMatchObject({ results: [], warnings: [], returned: 0, omitted: 0 });

    const failed = serve(() =>
      json({ engineTimings: [{ name: "Brave", status: "rate_limited", resultCount: 0, time: 9, errorReason: "HTTP 429" }], results: [] }),
    );
    await expect(webSearch(config(failed), { query: "q" })).rejects.toThrow(/every engine reported an error/);
    for (const [handler, pattern] of [
      [() => respond("{not json", "application/json"), /invalid JSON/],
      [() => json({ unexpected: true }), /unexpected response shape/],
      [() => respond("<html></html>", "text/html"), /unsupported content type/],
      [() => json({ error: "nope" }, 429), /HTTP 429/],
    ] as const) {
      const broken = serve(handler);
      await expect(webSearch(config(broken), { query: "q" })).rejects.toThrow(pattern);
    }
    await expect(webSearch(config(failed), { query: "  " })).rejects.toThrow(/query must not be empty/);
    await expect(webSearch(config(failed), { query: "q".repeat(2001) })).rejects.toThrow(/query exceeds 2000 characters/);
  });
});

describe("web_fetch", () => {
  test("returns Markdown, plain text, and JSON within body and excerpt bounds", async () => {
    const long = `${"a".repeat(11_999)}😀tail`;
    let accept = "";
    const routes: Record<string, () => Response> = {
      "/doc": () => respond("# Title\n\nBody.", "text/markdown; charset=utf-8"),
      "/data.json": () => respond('{"a":1}', "application/json"),
      "/huge": () => respond("x".repeat(2 * 1024 * 1024 + 1), "text/plain"),
      "/long": () => respond(long, "text/plain"),
    };
    const origin = serve((request) => {
      accept = request.headers.get("accept") ?? "";
      return routes[pathOf(request)]?.() ?? respond("plain body", "text/plain; charset=utf-8");
    });

    const markdown = await webFetch(config(origin), { url: `${origin}/doc` });
    expect(accept).toContain("text/markdown");
    expect(markdown).toMatchObject({ requestedUrl: `${origin}/doc`, finalUrl: `${origin}/doc`, extraction: "markdown", redirects: 0 });
    expect(markdown).toMatchObject({ content: "# Title\n\nBody.", truncated: false });
    expect(markdown.contentType).toContain("text/markdown");
    expect(await webFetch(config(origin), { url: `${origin}/notes` })).toMatchObject({ extraction: "text", content: "plain body" });
    expect((await webFetch(config(origin), { url: `${origin}/data.json` })).content).toBe('{"a":1}');
    await expect(webFetch(config(origin), { url: `${origin}/huge` })).rejects.toThrow(/exceeds 2097152 bytes/);
    expect(await webFetch(config(origin), { url: `${origin}/long` })).toMatchObject({ truncated: true, contentChars: long.length });
    expect((await webFetch(config(origin), { url: `${origin}/long` })).content).toBe("a".repeat(11_999));
  });

  test("follows bounded redirects and rejects invalid URLs, statuses, types, and a missing interpreter", async () => {
    const routes: Record<string, () => Response> = {
      "/a": () => redirect("/b"),
      "/b": () => redirect("/c", 301),
      "/c": () => respond("done", "text/plain"),
      "/creds": () => redirect("https://user:pass@example.com/x"),
      "/long": () => redirect(`https://example.com/${"b".repeat(4000)}`),
      "/page": () => respond("<html><body>page</body></html>", "text/html"),
      "/missing": () => new Response("gone", { status: 404, headers: { "content-type": "text/plain" } }),
    };
    const origin = serve((request) => routes[pathOf(request)]?.() ?? redirect("/loop"));

    expect(await webFetch(config(origin), { url: `${origin}/a` })).toMatchObject({ redirects: 2, finalUrl: `${origin}/c`, content: "done" });
    await expect(webFetch(config(origin), { url: `${origin}/loop` })).rejects.toThrow(/too many redirects \(limit 5\)/);
    await expect(webFetch(config(origin), { url: `${origin}/creds` })).rejects.toThrow(/embedded credentials/);
    await expect(webFetch(config(origin), { url: `${origin}/long` })).rejects.toThrow(/URL exceeds 4000 characters/);
    await expect(webFetch(config(origin), { url: `${origin}/missing` })).rejects.toThrow(/HTTP 404/);
    await expect(webFetch(config(origin), { url: "file:///etc/passwd" })).rejects.toThrow(/unsupported URL scheme/);
    await expect(webFetch(config(origin), { url: "example.com" })).rejects.toThrow(/invalid URL/);
    const image = serve(() => new Response(new Uint8Array([137, 80, 78, 71]), { headers: { "content-type": "image/png" } }));
    await expect(webFetch(config(image), { url: `${image}/pic.png` })).rejects.toThrow(/unsupported content type "image\/png"/);
    await expect(webFetch(config(origin, { python: join(fixtures, "absent-python") }), { url: `${origin}/page` })).rejects.toThrow(/could not run/);
  });

  test("aborts through the shared deadline helper", async () => {
    const stream = () => new ReadableStream({ async pull(c) { await Bun.sleep(25); c.enqueue(new TextEncoder().encode("chunk")); } });
    const slow = serve(() => new Response(stream(), { headers: { "content-type": "text/plain" } }));
    const cached = new AbortController();
    cached.abort();

    await expect(runWithDeadline(1000, cached.signal, "probe", async () => "done")).rejects.toThrow(/probe was cancelled/);
    await expect(runWithDeadline(25, undefined, "probe", (signal) => webFetch(config(slow), { url: `${slow}/slow` }, signal))).rejects.toThrow(
      /probe timed out after 25 ms/,
    );
    const controller = new AbortController();
    const pending = webFetch(config(slow), { url: `${slow}/slow` }, controller.signal);
    setTimeout(() => controller.abort(), 30);
    await expect(pending).rejects.toThrow(/web_fetch was cancelled/);
  });

  test.skipIf(!python)("extracts XHTML through the interpreter and fails on empty pages", async () => {
    const xhtml = `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Widget Guide</title><base href="https://cdn.example.com/base/"/>
<script>alert("do not keep this")</script></head><body><article><h1>Widget Guide</h1>
<p>Café — naïve widgets are small components; this paragraph explains why extraction matters for example documentation pages.</p>
<p>See <a href="../guide/intro.html">the introduction</a> for more context about widgets and their usage in practice.</p>
</article></body></html>`;
    const empty = '<html><body><div id="app"></div><script>renderApp()</script></body></html>';
    const origin = serve((request) =>
      pathOf(request) === "/empty" ? respond(empty, "text/html") : respond(xhtml, "application/xhtml+xml; charset=utf-8"),
    );

    const output = await webFetch(config(origin), { url: `${origin}/guide` });
    expect(output.extraction).toBe("trafilatura");
    expect(output.content).toContain("# Widget Guide");
    expect(output.content).toContain("Café — naïve");
    expect(output.content).toContain("(https://cdn.example.com/guide/intro.html)");
    expect(output.content).not.toContain("do not keep this");

    await expect(webFetch(config(origin), { url: `${origin}/empty` })).rejects.toThrow(/content extraction failed/);
  });
});

describe("extension contract", () => {
  interface RecordedTool {
    name: string;
    exposure?: string;
    namespace?: { name: string; instructions?: string };
    annotations?: Record<string, boolean>;
    parameters: any;
    outputSchema: any;
    execute: (toolCallId: string, params: any, signal?: AbortSignal) => Promise<any>;
  }

  function registered(origin: string, overrides: Partial<WebConfig> = {}): RecordedTool[] {
    const tools: RecordedTool[] = [];
    registerWebTools({ registerTool: (tool: RecordedTool) => void tools.push(tool) } as any, config(origin, overrides));
    return tools;
  }

  test("registers codemode tools whose structured output matches the declared schema", async () => {
    const origin = serve((request) => (request.url.includes("/api/search") ? json(searchResponse) : respond("# Page\n\nContent", "text/markdown")));
    const [searchTool, fetchTool] = registered(origin);

    expect([searchTool.name, fetchTool.name]).toEqual(["web_search", "web_fetch"]);
    for (const tool of [searchTool, fetchTool]) {
      expect(tool.exposure).toBe("codemode");
      expect(tool.annotations).toEqual({ readOnlyHint: true, destructiveHint: false, openWorldHint: true });
      expect(tool.namespace?.name).toBe("web");
      expect(tool.namespace?.instructions).toContain("untrusted");
      expect(tool.parameters).toMatchObject({ type: "object", additionalProperties: false });
    }
    expect([searchTool.parameters.required, fetchTool.parameters.required]).toEqual([["query"], ["url"]]);

    const search = await searchTool.execute("1", { query: "nix flakes" });
    const fetch = await fetchTool.execute("2", { url: `${origin}/page` });
    for (const [tool, output] of [[searchTool, search], [fetchTool, fetch]] as const) {
      for (const key of tool.outputSchema.required) expect(output.structuredContent).toHaveProperty(key);
      expect(JSON.parse(output.content[0].text)).toEqual(output.structuredContent);
    }
    for (const key of searchTool.outputSchema.properties.results.items.required) expect(search.structuredContent.results[0]).toHaveProperty(key);
    expect(fetch.structuredContent.extraction).toBe("markdown");
  });

  test(
    "releases the operation slot only after a cancelled extractor is reaped and then enforces the ceiling",
    async () => {
      // Runtime-agnostic fake extractor: it spawns a holder that inherits its stdio
      // and writes `finished` 1.2 s later, so the extractor's `close` event can only
      // fire once the holder exits. A fetch that rejects before awaiting `close`
      // would observe `finished` missing.
      const started = join(fixtures, "started");
      const finished = join(fixtures, "finished");
      const script = join(fixtures, "fake-extractor.mjs");
      writeFileSync(
        script,
        `import { spawn } from "node:child_process";\nimport { writeFileSync } from "node:fs";\n` +
          `if (process.argv[2] === "hold") {\n  setTimeout(() => writeFileSync(${JSON.stringify(finished)}, "finished"), 1200);\n} else {\n` +
          `  writeFileSync(${JSON.stringify(started)}, "started");\n` +
          `  spawn(process.execPath, [process.argv[1], "hold"], { stdio: "inherit" });\n  setTimeout(() => {}, 60_000);\n}\n`,
      );
      let openGate = () => {};
      const gate = new Promise<void>((resolve) => (openGate = resolve));
      const origin = serve(async (request) => {
        if (pathOf(request) !== "/plain") return respond("<html><body>page</body></html>", "text/html");
        await gate;
        return respond("# Page\n\nContent", "text/markdown");
      });
      const fetchTool = registered(origin, { python: process.execPath, extractScript: script })[1];

      const controller = new AbortController();
      const cancelled = fetchTool.execute("1", { url: `${origin}/page` }, controller.signal);
      await waitForFile(started);
      controller.abort();
      await expect(cancelled).rejects.toThrow(/web_fetch was cancelled/);
      expect(existsSync(finished)).toBe(true);

      // Four gated calls prove the slot was released; the fifth must be rejected.
      const pending = Array.from({ length: MAX_CONCURRENT_OPERATIONS }, (_unused, index) =>
        fetchTool.execute(String(index), { url: `${origin}/plain` }),
      );
      await expect(fetchTool.execute("over", { url: `${origin}/plain` })).rejects.toThrow(/already running/);
      openGate();
      for (const output of await Promise.all(pending)) expect(output.structuredContent.extraction).toBe("markdown");
    },
    20_000,
  );
});
