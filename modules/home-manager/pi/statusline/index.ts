import { homedir } from "node:os";
import { isAbsolute, join, relative, resolve, sep } from "node:path";
import type { ExtensionAPI, SessionEntry } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const RESET = "\x1b[0m";
const SEPARATOR = " │ ";
const GAUGE_BASE = 8;
const GAUGE_MAX = 20;
const MIN_GAP = 2;
const STATUS_BUDGET = 40;
const MIN_STATUS = 4;

const CONTROL_STRINGS = /(?:\x1b[\]PX^_]|[\x90\x98\x9d-\x9f])[\s\S]*?(?:\x07|\x1b\\|\x9c|$)/g;
const CSI = /(?:\x1b\[|\x9b)[0-?]*[ -/]*[@-~]/g;
const ESCAPES = /\x1b[ -/]*[@-~]/g;
const SGR = /\x1b\[[0-9;]*m/g;

function clean(text: string): string {
  return text
    .replace(CONTROL_STRINGS, "")
    .replace(CSI, "")
    .replace(ESCAPES, "")
    .replace(/\s+/gu, " ")
    .replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g, "");
}

function plain(text: string): string {
  return clean(text).trim();
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

function statusText(statuses: ReadonlyMap<string, string>, separator: string): string {
  const parts: string[] = [];
  for (const [, raw] of [...statuses].sort(([a], [b]) => a.localeCompare(b))) {
    const text = raw.replace(CONTROL_STRINGS, "");
    let safe = "";
    let last = 0;
    for (const match of text.matchAll(SGR)) {
      safe += clean(text.slice(last, match.index)) + match[0];
      last = match.index + match[0].length;
    }
    safe = (safe + clean(text.slice(last))).replace(/ {2,}/g, " ").trim();
    if (visibleWidth(plain(safe)) > 0) parts.push(`${safe}${RESET}`);
  }
  return parts.join(separator);
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

function levelColor(percent: number): "success" | "warning" | "error" {
  return percent >= 80 ? "error" : percent >= 50 ? "warning" : "success";
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
          const color = displayPercent === null ? "muted" : levelColor(displayPercent);
          const percentLabel = displayPercent === null ? "?" : `${displayPercent}%`;
          const percentPart = theme.fg(color, percentLabel);
          const counts = contextWindow > 0
            ? `${rawTokens === null ? "?" : formatTokens(rawTokens)}/${formatTokens(contextWindow)}`
            : rawTokens === null ? "" : formatTokens(rawTokens);
          const countsPart = counts ? theme.fg("mdCode", counts) : "";
          const unknownPart = counts ? rawTokens === null ? countsPart : `${countsPart} ?` : "?";
          const gauge = (cells: number): string => {
            if (displayPercent === null) return "";
            const filled = Math.round((displayPercent / 100) * cells);
            return `${theme.fg("dim", "[")}${theme.fg(color, "█".repeat(filled))}${theme.fg("dim", `${"░".repeat(cells - filled)}]`)}`;
          };

          const model = ctx.model;
          const provider = model ? plain(model.provider) : "";
          const modelId = model ? plain(model.id) : "";
          const thinking = model?.reasoning ? ` ${plain(pi.getThinkingLevel())}` : "";
          const modelText = model ? [provider, modelId].filter(Boolean).join("/") || "model" : "no model";
          const compactText = model ? modelId || provider || "model" : "no model";
          const modelColor = model ? "accent" : "dim";
          const modelPart = (text: string, available: number): string =>
            visibleWidth(text) > available
              ? theme.fg(modelColor, truncateToWidth(text, Math.max(0, available), "…"))
              : theme.fg(modelColor, text);
          const fullModel = modelPart(modelText, Number.POSITIVE_INFINITY) + (thinking ? theme.fg("dim", thinking) : "");
          const compactModel = modelPart(compactText, Number.POSITIVE_INFINITY) + (thinking ? theme.fg("dim", thinking) : "");

          const directoryPart = theme.fg("muted", formatCwd(ctx.cwd, homedir()));
          const branch = plain(footerData.getGitBranch() ?? "");
          const branchPart = theme.fg("mdLink", `⎇ ${branch || "—"}`);
          const sep = theme.fg("dim", SEPARATOR);
          const status = statusText(footerData.getExtensionStatuses(), sep) || theme.fg("dim", "—");
          const cost = sessionCost(ctx.sessionManager.getEntries());
          const costPart = theme.fg("success", `$${cost.toFixed(3)}`);

          const group = (parts: string[]): string => parts.filter(Boolean).join(sep);
          const contextPart = (withGauge: boolean, withCounts: boolean, cells: number): string => {
            if (percent === null) return unknownPart;
            return [withGauge ? gauge(cells) : "", withCounts ? countsPart : "", percentPart].filter(Boolean).join(" ");
          };
          const right = (withCost: boolean, withGauge: boolean, withCounts: boolean, cells: number): string =>
            group([withCost ? costPart : "", contextPart(withGauge, withCounts, cells)]);
          const left = (withIdentity: boolean, modelValue: string, statusValue: string): string =>
            group([withIdentity ? directoryPart : "", withIdentity ? branchPart : "", modelValue, statusValue]);

          const stages = [
            { identity: true, compact: false, cost: true, gauge: true, counts: true },
            { identity: true, compact: true, cost: true, gauge: true, counts: true },
            { identity: false, compact: true, cost: true, gauge: true, counts: true },
            { identity: false, compact: true, cost: false, gauge: true, counts: true },
            { identity: false, compact: true, cost: false, gauge: false, counts: true },
            { identity: false, compact: true, cost: false, gauge: false, counts: false },
          ];

          let selected = "";
          for (const stage of stages) {
            const coreLeft = left(stage.identity, stage.compact ? compactModel : fullModel, "");
            const coreRight = right(stage.cost, stage.gauge, stage.counts, GAUGE_BASE);
            const coreWidth = visibleWidth(coreLeft) + visibleWidth(coreRight) + (coreLeft && coreRight ? MIN_GAP : 0);
            if (coreWidth > w) continue;

            let statusPart = "";
            if (coreLeft && coreRight) {
              const room = w - coreWidth - visibleWidth(sep);
              const full = visibleWidth(status);
              const budget = Math.min(full, STATUS_BUDGET, room);
              if (budget === full) statusPart = status;
              else if (budget >= MIN_STATUS) statusPart = truncateToWidth(status, budget, "…");
            }
            const contentLeft = left(stage.identity, stage.compact ? compactModel : fullModel, statusPart);
            const spare = w - visibleWidth(contentLeft) - visibleWidth(coreRight) - MIN_GAP;
            const grown = stage.gauge && displayPercent !== null
              ? Math.min(GAUGE_MAX - GAUGE_BASE, Math.max(0, Math.floor(spare / 2)))
              : 0;
            selected = contentLeft + " ".repeat(MIN_GAP + spare) + coreRight;
            if (grown > 0) {
              const grownRight = right(stage.cost, stage.gauge, stage.counts, GAUGE_BASE + grown);
              const gap = w - visibleWidth(contentLeft) - visibleWidth(grownRight);
              selected = contentLeft + " ".repeat(gap) + grownRight;
            }
            break;
          }

          if (!selected) {
            const rightPart = percentPart;
            const available = w - MIN_GAP - visibleWidth(rightPart);
            if (available >= 1) {
              const thinkingWidth = thinking ? visibleWidth(thinking) : 0;
              const keepThinking = available - thinkingWidth >= MIN_STATUS;
              const modelValueText = keepThinking ? modelPart(compactText, available - thinkingWidth) : modelPart(compactText, available);
              selected = modelValueText + (keepThinking ? theme.fg("dim", thinking) : "");
              selected += " ".repeat(w - visibleWidth(selected) - visibleWidth(rightPart)) + rightPart;
            } else {
              selected = " ".repeat(Math.max(0, w - visibleWidth(rightPart))) + rightPart;
            }
          }

          return [visibleWidth(selected) > w ? truncateToWidth(selected, w, "…") : selected];
        },
      };
    });
  });
}
