import {
  CustomEditor, keyHint, renderDiff, truncateToVisualLines,
  type ExtensionUIContext, type ExtensionAPI, type Theme, type ThemeColor, type ToolRenderers,
} from "@earendil-works/pi-coding-agent";
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
function component(lines: (width: number) => string[]): Component {
  return {
    invalidate() {},
    render(width) {
      if (width <= 0) return lines(1).map(() => "");
      // Share native outputPad with assistant text and expanded thinking.
      return lines(width).map((line) => truncateToWidth(line, width));
    },
  };
}

function textLines(text: string, color: ThemeColor, theme: Theme, width: number): string[] {
  if (!text) return [];
  return clean(text).split("\n").flatMap((line) =>
    wrapTextWithAnsi(theme.fg(color, line), width).map((part) => truncateToWidth(part, width)),
  );
}

function styledLines(text: string, width: number): string[] {
  return text.split("\n").flatMap((line) => wrapTextWithAnsi(line, width));
}

function previewLines(source: string, width: number): string[] {
  // Bound work BEFORE word diffing, including huge single logical lines.
  const prefix = source.slice(0, 8192).split("\n", 16).join("\n");
  const preview = truncateToVisualLines(renderDiff(clean(prefix)), 16, width, 0, "start");
  if (prefix.length < source.length || preview.skippedCount > 0) {
    preview.visualLines.push(...wrapTextWithAnsi(`… more (${keyHint("app.tools.expand", "expand")})`, width));
  }
  return preview.visualLines;
}

function argumentLines(args: Record<string, unknown>, theme: Theme, width: number): string[] {
  return Object.entries(args).flatMap(([key, value]) => {
    const text = typeof value === "string" ? value : JSON.stringify(value, null, 2);
    return text === undefined ? [] : textLines(`${key}: ${text}`, "dim", theme, width);
  });
}

function renderers(name: string): ToolRenderers {
  return {
    renderCall(args, theme, context: Context) {
      const callArgs = isRecord(args) ? args : {};
      return component((width) => {
        const color = context.isError ? "error" : context.isPartial ? "warning" : "success";
        const metadata = context.state[ROW]; // renderResult has run before this closure is rendered.
        const prefix = `${theme.fg(color, "■")} ${theme.fg("toolTitle", name)} `;
        const stats = metadata?.stats ?? "";
        const suffix = stats && width > visibleWidth(prefix) + visibleWidth(stats) + 2 ? theme.fg("dim", stats) : "";
        const available = width - visibleWidth(prefix) - (suffix ? visibleWidth(stats) + 2 : 0);
        const detail = inline(summary(name, callArgs, context.cwd));
        const preview = clean(truncateToWidth(detail, Math.min(Math.max(0, available), name === "bash" || name === "codemode" ? 96 : width)));
        const subject = context.isError && metadata?.error ? `${metadata.error}  ${preview}` : preview;
        // Truncation inserts resets; strip those before styling so the background stays continuous.
        const left = available > 0
          ? prefix + theme.fg(context.isError ? "error" : "toolOutput", clean(truncateToWidth(subject, available)))
          : theme.fg(color, clean(truncateToWidth(`■ ${name}`, width)));
        const row = left + " ".repeat(Math.max(0, width - visibleWidth(left) - visibleWidth(suffix))) + suffix;
        return [row, ...(context.expanded ? ["", ...argumentLines(callArgs, theme, width)] : [])];
      });
    },
    renderResult(result, options, theme, context: Context) {
      const output = result.content.filter((block) => block.type === "text").map((block) => block.text).join("\n");
      const diff = string(result.details?.diff);
      const confirmed = !context.isError && !options.isPartial;
      const nativeEditDiff = name === "edit" && confirmed && /^[+-]\s*\d+ /m.test(diff);
      const count = output.trim() ? output.trimEnd().split("\n").length : 0;
      const stats = nativeEditDiff
        ? `+${(diff.match(/^\+\s*\d+ /gm) ?? []).length}/-${(diff.match(/^-\s*\d+ /gm) ?? []).length}`
        : count ? `${count} ${count === 1 ? "line" : "lines"}` : "";
      const errorText = clean(output).split("Script error:").at(-1) ?? "";
      const error = errorText.split("\n").find((line) => /error|failed|denied|not found|exit.*code|timed out/i.test(line)) ?? firstLine(errorText);
      context.state[ROW] = { stats, error: inline(error) };
      return component((width) => {
        if (!options.expanded) {
          return confirmed && diff.trim() ? previewLines(diff, width) : [];
        }
        const lines: string[] = [""];
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
        if (diff.trim()) {
          if (!confirmed) lines.push(...textLines("Unconfirmed/reported diff", "warning", theme, width));
          // Sanitize only raw input: native ANSI includes inverse word-change highlights.
          lines.push(...styledLines(renderDiff(clean(diff)), width));
        }
        const fullPath = string(result.details?.fullOutputPath);
        if (result.details?.truncation?.truncated) lines.push(...textLines("Output truncated by tool.", "warning", theme, width));
        if (fullPath) lines.push(...textLines(`Full output: ${fullPath}`, "dim", theme, width));
        return lines;
      });
    },
  };
}

class PromptEditor extends CustomEditor {
  override setPaddingX(padding: number): void {
    super.setPaddingX(Math.max(2, padding));
  }

  override render(width: number): string[] {
    const lines = super.render(width);
    // Replace only native padding: text, cursor markers and mouse geometry stay intact.
    if (width >= 5 && this.getPaddingX() >= 2 && lines[1]?.startsWith("  ")) {
      lines[1] = this.borderColor("❯") + " " + lines[1].slice(2);
    }
    return lines;
  }
}

export default function compact(pi: ExtensionAPI): void {
  pi.registerToolRenderer((name, next) => TOOLS.has(name) ? renderers(name) : next());
  pi.registerMarkdownTransformer((markdown, context) =>
    context.messageType === "user" && markdown.trim() ? `## ❯ You\n\n${markdown}` : markdown,
  );
  const editorFactory: NonNullable<ReturnType<ExtensionUIContext["getEditorComponent"]>> = (tui, theme, keybindings) =>
    new PromptEditor(tui, theme, keybindings, { paddingX: 2, embedWorkingStatus: false });
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    // Native resetExtensionUI clears this on reload/replacement; don't clobber other overrides at shutdown.
    ctx.ui.setHiddenThinkingLabel("Thinking...");
    if (ctx.ui.getEditorComponent() === undefined) {
      ctx.ui.setEditorComponent(editorFactory);
    }
  });
  pi.on("session_shutdown", (_event, ctx) => {
    if (ctx.mode === "tui" && ctx.ui.getEditorComponent() === editorFactory) {
      ctx.ui.setEditorComponent(undefined);
    }
  });
}
