import {
  CustomEditor, keyHint, renderDiff, truncateToVisualLines,
  type ExtensionUIContext, type ExtensionAPI, type Theme, type ThemeColor, type ToolRenderers,
} from "@earendil-works/pi-coding-agent";
import { Container, getCapabilities, getImageDimensions, imageFallback, MouseRegion, Spacer, truncateToWidth, visibleWidth, wrapTextWithAnsi, type Component } from "@earendil-works/pi-tui";

const TOOLS = new Set(["read", "bash", "edit", "write", "grep", "find", "ls", "codemode", "tool_search"]);
const ROW = Symbol("compact.row");
const CHILD = Symbol("compact.child");
type ChildState = { parent: boolean; open: Map<number, boolean> };
type RowState = { [ROW]?: { stats: string; error: string }; [CHILD]?: ChildState };
type Context = Omit<Parameters<NonNullable<ToolRenderers["renderCall"]>>[2], "state"> & { state: RowState };
const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const string = (value: unknown): string => typeof value === "string" ? value : "";

// Strip terminal commands, including unterminated strings; preserve Unicode/newlines.
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

function component(lines: (width: number) => string[]): Component {
  return {
    invalidate() {},
    render(width) {
      if (width <= 0) return lines(1).map(() => "");
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

function omissionLine(label: string, theme: Theme, width: number): string {
  const key = clean(keyHint("app.tools.expand", "")).trim();
  const suffix = key ? ` (${key})` : "";
  const full = label + suffix;
  const room = width - visibleWidth(suffix);
  const text = visibleWidth(full) <= width
    ? full
    : room > 0
      ? truncateToWidth(label, room, "") + suffix
      : truncateToWidth(suffix.trim(), width, "…");
  // Style after truncation to preserve the native Box background.
  return theme.fg("muted", clean(text));
}

function previewLines(source: string, theme: Theme, width: number): string[] {
  // Bound input before native word diffing.
  const prefix = source.slice(0, 8192).split("\n", 16).join("\n");
  const preview = truncateToVisualLines(renderDiff(clean(prefix)), 16, width, 0, "start");
  if (prefix.length < source.length || preview.skippedCount > 0) {
    preview.visualLines.push(omissionLine("… more", theme, width));
  }
  return preview.visualLines;
}

function callPreview(call: Record<string, unknown>, name: string, cwd: string): string {
  const recorded = string(call.args);
  try {
    const parsed: unknown = JSON.parse(recorded);
    if (isRecord(parsed)) {
      const text = inline(summary(name, parsed, cwd));
      if (text) return text;
    }
  } catch {
    // Native argument previews may be truncated JSON or plain strings.
  }
  return inline(recorded);
}

const STATUS = new Map<string, { symbol: string; color: ThemeColor }>([
  ["running", { symbol: "…", color: "warning" }],
  ["ok", { symbol: "✓", color: "success" }],
  ["error", { symbol: "✗", color: "error" }],
  ["cancelled", { symbol: "⊘", color: "muted" }],
]);

function formatDuration(value: unknown): string {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return "";
  const ms = Math.round(value);
  return ms < 1000 ? `${ms}ms` : `${(value / 1000).toFixed(1)}s`;
}

function formatCost(value: unknown): string {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return "";
  return `$${value === 0 ? "0.00" : value >= 0.01 ? value.toFixed(2) : value.toPrecision(2)}`;
}

function headerLine(call: Record<string, unknown>, theme: Theme, width: number, cwd: string): string {
  const status = STATUS.get(string(call.status)) ?? { symbol: "?", color: "dim" as const };
  const name = inline(string(call.name)) || "?";
  const preview = callPreview(call, string(call.name), cwd);
  const lead = "  ";
  const headWidth = visibleWidth(lead) + visibleWidth(status.symbol) + 1;
  if (width <= headWidth) {
    return theme.fg(status.color, clean(truncateToWidth(lead + status.symbol, width)));
  }
  const nameWidth = width - headWidth;
  const shownName = clean(truncateToWidth(name, nameWidth));
  const row = lead + theme.fg(status.color, status.symbol) + " " + theme.fg("toolTitle", shownName);
  if (visibleWidth(shownName) >= nameWidth) return row;
  const remaining = width - headWidth - visibleWidth(shownName);
  const duration = formatDuration(call.durationMs);
  const fullMetadata = [duration, formatCost(call.cost)].filter(Boolean).join(" ");
  const metadata = visibleWidth(fullMetadata) + 2 <= remaining ? fullMetadata : duration;
  const metaWidth = visibleWidth(metadata);
  const metaFits = metaWidth > 0 && remaining >= metaWidth + 2;
  // Cap previews like the parent command, reserving a two-column metadata gap.
  const argsWidth = Math.max(0, Math.min(96, remaining - (metaFits ? metaWidth + 3 : 1)));
  const shownArgs = argsWidth > 0 && preview ? clean(truncateToWidth(preview, argsWidth)) : "";
  let line = row;
  if (shownArgs) line += theme.fg("muted", ` ${shownArgs}`);
  if (!metaFits) return line;
  const used = visibleWidth(line);
  return line + " ".repeat(Math.max(0, width - used - metaWidth)) + theme.fg("dim", metadata);
}

function detailLines(call: Record<string, unknown>, theme: Theme, width: number): string[] {
  const pad = " ".repeat(Math.min(4, width - 1));
  const inner = width - pad.length;
  const lines: string[] = [];
  const args = string(call.args);
  if (args) lines.push(...textLines(`args: ${args}`, "dim", theme, inner).map((line) => pad + line));
  const error = string(call.error);
  if (error) lines.push(...textLines(`error: ${error}`, "error", theme, inner).map((line) => pad + line));
  return lines;
}

function childState(context: Context): ChildState {
  const existing = context.state[CHILD];
  if (existing?.parent === context.expanded) return existing;
  const next = { parent: context.expanded, open: new Map<number, boolean>() };
  context.state[CHILD] = next;
  return next;
}

function childComponents(calls: unknown[], indices: number[], context: Context, theme: Theme): Container {
  const state = childState(context);
  const container = new Container();
  for (const index of indices) {
    const call = isRecord(calls[index]) ? calls[index] : {};
    const open = state.open.get(index) ?? context.expanded;
    const header = component((width) => [headerLine(call, theme, width, context.cwd)]);
    container.addChild(new MouseRegion(header, (event) => {
      if (event.type !== "click" || event.button !== "left") return undefined;
      state.open.set(index, !(state.open.get(index) ?? context.expanded));
      context.invalidate();
      return { handled: true };
    }));
    if (open) container.addChild(component((width) => detailLines(call, theme, width)));
  }
  return container;
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
        // Strip truncation resets before styling to preserve the background.
        const left = available > 0
          ? prefix + theme.fg(context.isError ? "error" : "toolOutput", clean(truncateToWidth(subject, available)))
          : theme.fg(color, clean(truncateToWidth(`■ ${name}`, width)));
        const row = left + " ".repeat(Math.max(0, width - visibleWidth(left) - visibleWidth(suffix))) + suffix;
        return [row, ...(context.expanded ? ["", ...argumentLines(callArgs, theme, width)] : [])];
      });
    },
    renderResult(result, options, theme, context: Context) {
      const textOutput = result.content.filter((block) => block.type === "text").map((block) => block.text).join("\n");
      // Mirror native getTextOutput: attach fallback indicators only when Pi
      // cannot render the images itself; otherwise it adds the image components.
      const images = result.content.filter((block) => block.type === "image");
      const fallback = images.length > 0 && (!getCapabilities().images || !context.showImages)
        ? images.map((block) => imageFallback(
            block.mimeType ?? "image/unknown",
            block.data && block.mimeType ? getImageDimensions(block.data, block.mimeType) ?? undefined : undefined,
          )).join("\n")
        : "";
      const output = [textOutput, fallback].filter(Boolean).join("\n");
      const diff = string(result.details?.diff);
      const confirmed = !context.isError && !options.isPartial;
      const nativeEditDiff = name === "edit" && confirmed && /^[+-]\s*\d+ /m.test(diff);
      const count = output.trim() ? output.trimEnd().split("\n").length : 0;
      const calls: unknown[] | undefined = name === "codemode" && Array.isArray(result.details?.calls)
        ? result.details.calls
        : undefined;
      // Provisional call IDs change on completion; expansion follows original indices.
      const indices = calls?.flatMap((call, index) =>
        isRecord(call) && inline(string(call.name)) ? [index] : []) ?? [];
      const stats = indices.length
        ? `${indices.length} ${indices.length === 1 ? "call" : "calls"}`
        : nativeEditDiff
          ? `+${(diff.match(/^\+\s*\d+ /gm) ?? []).length}/-${(diff.match(/^-\s*\d+ /gm) ?? []).length}`
          : count ? `${count} ${count === 1 ? "line" : "lines"}` : "";
      const errorText = clean(output).split("Script error:").at(-1) ?? "";
      const error = errorText.split("\n").find((line) => /error|failed|denied|not found|exit.*code|timed out/i.test(line)) ?? firstLine(errorText);
      context.state[ROW] = { stats, error: inline(error) };
      childState(context); // Track parent transitions even while no child rows are visible.
      const shown = options.expanded ? indices : indices.slice(-4);
      const hidden = indices.length - shown.length;
      const container = new Container();
      if (!options.expanded) {
        if (hidden > 0) {
          const label = `… ${hidden} earlier ${hidden === 1 ? "call" : "calls"}`;
          container.addChild(component((width) => [omissionLine(label, theme, width)]));
        }
        if (calls && shown.length) container.addChild(childComponents(calls, shown, context, theme));
        if (confirmed && diff.trim()) container.addChild(component((width) => previewLines(diff, theme, width)));
        return container;
      }
      container.addChild(new Spacer(1));
      if (calls && indices.length) container.addChild(childComponents(calls, indices, context, theme));
      if (output) container.addChild(component((width) => textLines(output, context.isError ? "error" : "toolOutput", theme, width)));
      if (diff.trim()) {
        if (!confirmed) container.addChild(component((width) => textLines("Unconfirmed/reported diff", "warning", theme, width)));
        // Sanitize only raw input: native ANSI includes inverse word-change highlights.
        container.addChild(component((width) => styledLines(renderDiff(clean(diff)), width)));
      }
      const fullPath = string(result.details?.fullOutputPath);
      if (result.details?.truncation?.truncated) {
        container.addChild(component((width) => textLines("Output truncated by tool.", "warning", theme, width)));
      }
      if (fullPath) container.addChild(component((width) => textLines(`Full output: ${fullPath}`, "dim", theme, width)));
      return container;
    },
  };
}

class PromptEditor extends CustomEditor {
  override setPaddingX(padding: number): void {
    super.setPaddingX(Math.max(2, padding));
  }

  override render(width: number): string[] {
    const lines = super.render(width);
    // Replace only padding, preserving cursor and mouse geometry.
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
    // Pi resets this on reload; don't overwrite other extensions at shutdown.
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
