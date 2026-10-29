import type { ExtensionAPI, Theme, ThemeColor, ToolRenderers } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth, wrapTextWithAnsi, type Component } from "@earendil-works/pi-tui";

const TOOLS = new Set(["read", "bash", "edit", "write", "grep", "find", "ls", "codemode", "tool_search"]);
const ROW = Symbol("compact.row");
type RowState = { [ROW]?: { stats: string; error: string } };
type Context = Omit<Parameters<NonNullable<ToolRenderers["renderCall"]>>[2], "state"> & { state: RowState };
const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const string = (value: unknown): string => typeof value === "string" ? value : "";

// Remove terminal commands, including unterminated control strings. Keep Unicode and
// logical newlines in expanded text; never let input supply terminal styling.
function clean(text: string): string {
  return text
    .replace(/(?:\x1b[\]PX^_]|[\x90\x98\x9d-\x9f])[\s\S]*?(?:\x07|\x1b\\|\x9c|$)/g, "")
    .replace(/(?:\x1b\[|\x9b)[0-?]*[ -/]*[@-~]/g, "")
    .replace(/\x1b[ -/]*[@-~]/g, "")
    .replace(/\t/g, "  ")
    .replace(/[\x00-\x09\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g, "");
}
const inline = (text: string): string => clean(text).replace(/\s+/gu, " ").trim();
const firstLine = (text: string): string => clean(text).split(/\n|\u2028|\u2029/u).find((line) => line.trim())?.trim() ?? "";

function summary(name: string, args: Record<string, unknown>, cwd: string): string {
  let path = string(args.path);
  if (cwd && path.startsWith(`${cwd}/`)) path = path.slice(cwd.length + 1);
  if (name === "bash") return firstLine(string(args.command));
  if (name === "codemode") return firstLine(string(args.code));
  if (name === "tool_search") return string(args.query);
  if (name === "grep" || name === "find") return `${string(args.pattern)} in ${path || "."}`;
  if (name === "read") {
    const offset = typeof args.offset === "number" && Number.isFinite(args.offset) ? args.offset : 1;
    const limit = typeof args.limit === "number" && Number.isFinite(args.limit) ? args.limit : undefined;
    if (args.offset != null || limit !== undefined) path += `:${offset}–${limit === undefined ? "" : offset + limit - 1}`;
  }
  return path || (name === "ls" ? "." : "");
}

// Stateless layout: theme and width are evaluated on every render. Pi owns redraws.
function component(context: Context, lines: (width: number) => string[]): Component {
  return {
    invalidate() {},
    render(width) {
      if (width <= 0) return lines(1).map(() => "");
      const pad = " ".repeat(Math.max(0, Math.min(Math.floor(context.outputPad), Math.floor((width - 1) / 2))));
      const inner = width - 2 * visibleWidth(pad);
      return lines(inner).map((line) => pad + truncateToWidth(line, inner) + pad);
    },
  };
}

function textLines(text: string, color: ThemeColor, theme: Theme, width: number): string[] {
  if (!text) return [];
  return clean(text).split("\n").flatMap((line) =>
    wrapTextWithAnsi(theme.fg(color, line), width).map((part) => truncateToWidth(part, width)),
  );
}

function argumentLines(args: Record<string, unknown>, theme: Theme, width: number): string[] {
  return Object.entries(args).flatMap(([key, value]) => {
    const text = typeof value === "string" ? value : JSON.stringify(value, null, 2);
    return text === undefined ? [] : textLines(`${key}: ${text}`, "dim", theme, width);
  });
}

function renderers(name: string): ToolRenderers {
  return {
    renderShell: "self",
    renderCall(args, theme, context: Context) {
      const callArgs = isRecord(args) ? args : {};
      return component(context, (width) => {
        const status = context.isError ? "error" : !context.isPartial ? "done" : context.executionStarted ? "running" : "preparing";
        const color = context.isError ? "error" : !context.isPartial ? "success" : "warning";
        const metadata = context.state[ROW]; // renderResult has run before this closure is rendered.
        const prefix = `${theme.fg(color, `[${status}]`)} ${theme.fg("toolTitle", name)} `;
        const detail = inline(summary(name, callArgs, context.cwd));
        const subject = context.isError && metadata?.error ? `${metadata.error} · ${detail}` : detail;
        const suffix = !context.isError && metadata?.stats ? theme.fg("dim", ` · ${metadata.stats}`) : "";
        const available = width - visibleWidth(prefix) - visibleWidth(suffix);
        const row = available > 0
          ? prefix + theme.fg(context.isError ? "error" : "toolOutput", truncateToWidth(subject, available)) + suffix
          : truncateToWidth(prefix + theme.fg("toolOutput", subject) + suffix, width);
        return [row, ...(context.expanded ? argumentLines(callArgs, theme, width) : [])];
      });
    },
    renderResult(result, options, theme, context: Context) {
      const output = result.content.filter((block) => block.type === "text").map((block) => block.text).join("\n");
      const diff = name === "edit" ? string(result.details?.diff) : "";
      const diffLines = diff.split("\n");
      const count = output.trim() ? output.trimEnd().split("\n").length : 0;
      const stats = diff
        ? `+${diffLines.filter((line) => line.startsWith("+")).length}/-${diffLines.filter((line) => line.startsWith("-")).length}`
        : count ? `${count} ${count === 1 ? "line" : "lines"}` : "";
      const errorText = clean(output).split("Script error:").at(-1) ?? "";
      const error = errorText.split("\n").find((line) => /error|failed|denied|not found|exit.*code|timed out/i.test(line)) ?? firstLine(errorText);
      context.state[ROW] = { stats, error: inline(error) };
      return component(context, (width) => {
        if (!options.expanded) return [];
        const lines: string[] = [];
        // Codemode's recorded calls contain bounded args/errors, not nested tool output.
        // Render them directly: upstream call renderers start clocks or read edit previews.
        if (name === "codemode" && Array.isArray(result.details?.calls)) {
          for (const call of result.details.calls) {
            const color = call.status === "error" ? "error" : call.status === "ok" ? "success" : "warning";
            lines.push(...textLines(`[${string(call.status)}] ${string(call.name)} ${string(call.args)}`, color, theme, width));
            lines.push(...textLines(string(call.error), "error", theme, width));
            if (typeof call.durationMs === "number") lines.push(...textLines(`${call.durationMs}ms`, "dim", theme, width));
            if (typeof call.cost === "number") lines.push(...textLines(`Cost: $${call.cost}`, "dim", theme, width));
          }
        }
        lines.push(...textLines(output, context.isError ? "error" : "toolOutput", theme, width));
        for (const line of diff ? diffLines : []) {
          const color = line.startsWith("+") ? "toolDiffAdded" : line.startsWith("-") ? "toolDiffRemoved" : "toolDiffContext";
          lines.push(...textLines(line || " ", color, theme, width));
        }
        const fullPath = string(result.details?.fullOutputPath);
        if (result.details?.truncation?.truncated) lines.push(...textLines("Output truncated by tool.", "warning", theme, width));
        if (fullPath) lines.push(...textLines(`Full output: ${fullPath}`, "dim", theme, width));
        return lines;
      });
    },
  };
}

export default function compact(pi: ExtensionAPI): void {
  pi.registerToolRenderer((name, next) => TOOLS.has(name) ? renderers(name) : next());
}
