import { homedir } from "node:os";
import { isAbsolute, join, relative, resolve, sep } from "node:path";
import type { ExtensionAPI, SessionEntry } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const SEPARATOR = " │ ";
const MIN_GAP = 2;
const GAUGE_CELLS = 10;

const CONTROL_STRINGS = /(?:\x1b[\]PX^_]|[\x90\x98\x9d-\x9f])[\s\S]*?(?:\x07|\x1b\\|\x9c|$)/g;
const CSI = /(?:\x1b\[|\x9b)[0-?]*[ -/]*[@-~]/g;
const ESCAPES = /\x1b[ -/]*[@-~]/g;

function plain(text: string): string {
  return text
    .replace(CONTROL_STRINGS, "")
    .replace(CSI, "")
    .replace(ESCAPES, "")
    .replace(/\s+/gu, " ")
    .replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g, "")
    .trim();
}

function relativeInside(base: string, target: string): string | null {
  const value = relative(base, target);
  return value === "" || (value !== ".." && !value.startsWith(`..${sep}`) && !isAbsolute(value)) ? value : null;
}

function formatCwd(cwd: unknown, home: string): string {
  const safe = typeof cwd === "string" ? plain(cwd) : "";
  const base = resolve(home);
  if (!safe) return "—";
  const target = resolve(safe);
  const homePath = relativeInside(base, target);
  if (homePath === null) return target;
  if (homePath === "") return "~";
  const projects = join(base, "projects");
  const projectPath = relativeInside(projects, target);
  if (projectPath === null) return `~${sep}${homePath}`;
  return projectPath === "" ? `~${sep}projects` : projectPath;
}

function formatTokens(count: number): string {
  if (count < 1000) return `${Math.round(count)}`;
  if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
  if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
  return `${Math.round(count / 1_000_000)}M`;
}

function amount(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function usageCost(usage: unknown): number {
  if (!isRecord(usage) || !isRecord(usage.cost)) return 0;
  return amount(usage.cost.total);
}

function sessionCost(entries: Iterable<SessionEntry>): number {
  let total = 0;
  for (const entry of entries) {
    if (entry.type === "usage") total += usageCost(entry.usage);
    else if (entry.type === "compaction" || entry.type === "branch_summary") total += usageCost(entry.usage);
    else if (entry.type === "message") {
      if (entry.message.role === "assistant") total += usageCost(entry.message.usage);
      else if (entry.message.role === "toolResult") total += usageCost(entry.message.usage);
    }
  }
  return total;
}

function clampPercent(value: number): number {
  return Math.min(100, Math.max(0, value));
}

function levelColor(tokens: number | null, percent: number | null): "success" | "warning" | "error" {
  if ((tokens ?? 0) >= 200_000 || (percent ?? 0) >= 80) return "error";
  if ((tokens ?? 0) >= 100_000 || (percent ?? 0) >= 50) return "warning";
  return "success";
}

export default function statusline(pi: ExtensionAPI): void {
  let redraw: (() => void) | undefined;

  const refresh = () => redraw?.();
  pi.on("model_select", refresh);
  pi.on("thinking_level_select", refresh);

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      const draw = () => tui.requestRender();
      redraw = draw;
      const unsubscribe = footerData.onBranchChange(draw);

      return {
        invalidate() {},
        dispose() {
          unsubscribe();
          if (redraw === draw) redraw = undefined;
        },
        render(width: number): string[] {
          const w = Math.max(0, Math.floor(width));
          if (w === 0) return [""];

          const usage = ctx.getContextUsage();
          const contextWindow = amount(usage?.contextWindow) || amount(ctx.model?.contextWindow);
          const rawPercent = typeof usage?.percent === "number" && Number.isFinite(usage.percent) ? usage.percent : null;
          const rawTokens = typeof usage?.tokens === "number" && Number.isFinite(usage.tokens) ? usage.tokens : null;
          const percent = rawPercent === null ? null : clampPercent(rawPercent);
          const displayPercent = percent === null ? null : Math.round(percent);
          const color = levelColor(rawTokens, displayPercent);
          const percentLabel = displayPercent === null ? "?" : `${displayPercent}%`;
          const percentPart = theme.fg(color, percentLabel);
          const countsPart = theme.fg(color, rawTokens === null ? "?" : formatTokens(rawTokens))
            + (contextWindow > 0 ? theme.fg("dim", `/${formatTokens(contextWindow)}`) : "");
          const filled = displayPercent === null ? 0 : Math.round(displayPercent / 100 * GAUGE_CELLS);
          const gauge = displayPercent === null
            ? theme.fg("dim", "[    ?     ]")
            : theme.fg("dim", "[") + theme.fg(color, "▮".repeat(filled)) + theme.fg("dim", "▯".repeat(GAUGE_CELLS - filled) + "]");

          const model = ctx.model;
          const modelId = model ? plain(model.id) || "no model" : "no model";
          const thinking = model?.reasoning ? ` ${plain(pi.getThinkingLevel())}` : "";
          const modelPart = theme.fg(model ? "accent" : "dim", modelId) + theme.fg("dim", thinking);

          const directoryPart = theme.fg("muted", formatCwd(ctx.cwd, homedir()));
          const branch = plain(footerData.getGitBranch() ?? "");
          const branchPart = theme.fg("muted", `⎇ ${branch || "—"}`);
          const sep = theme.fg("dim", SEPARATOR);
          const cost = sessionCost(ctx.sessionManager.getEntries());
          const costPart = theme.fg("dim", `$${cost.toFixed(3)}`);

          const contextPart = theme.fg("dim", "ctx ") + (
            rawTokens === null && displayPercent === null ? theme.fg("muted", "—") : `${gauge} ${countsPart} ${percentPart}`
          );
          const fields = [directoryPart, branchPart, modelPart, costPart, contextPart];
          const widths = fields.map((field) => Math.min(visibleWidth(field), w));
          const budget = Math.max(fields.length, w - 3 * visibleWidth(sep) - MIN_GAP);
          let used = widths.reduce((sum, size) => sum + size, 0);
          // Shorten other fields first; context yields only when their minimum won't fit.
          while (used > budget) {
            const otherWidth = Math.max(...widths.slice(0, -1));
            const widest = otherWidth > 1 ? widths.indexOf(otherWidth) : widths.length - 1;
            widths[widest]--;
            used--;
          }
          const parts = fields.map((field, index) => truncateToWidth(field, widths[index], "…"));
          const left = parts.slice(0, 3).join(sep);
          const right = parts.slice(3).join(sep);
          const gap = Math.max(MIN_GAP, w - visibleWidth(left) - visibleWidth(right));
          return [truncateToWidth(left + " ".repeat(gap) + right, w, "…")];
        },
      };
    });
  });
}
