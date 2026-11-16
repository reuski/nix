import { expect, test } from "bun:test";
import { homedir } from "node:os";
import { join } from "node:path";
import { stripVTControlCharacters } from "node:util";
import { Theme, type ExtensionAPI, type ReadonlyFooterDataProvider } from "@earendil-works/pi-coding-agent";
import { visibleWidth, type TUI } from "@earendil-works/pi-tui";
import statusline from "./index.ts";
import gruvbox from "../gruvbox.json";

type Footer = { render(width: number): string[]; dispose?(): void };
type Factory = (tui: TUI, theme: Theme, data: ReadonlyFooterDataProvider) => Footer;
const plainTheme = { fg: (_color: string, text: string) => text } as Theme;
const plain = (text: string) => stripVTControlCharacters(text);
const usage = (total: number) => ({ cost: { total } });

function harness(mode = "tui", theme = plainTheme) {
  const state = {
    model: { provider: "openai", id: "gpt-5", reasoning: true, contextWindow: 200_000 } as
      { provider: string; id: string; reasoning?: boolean; contextWindow?: number } | undefined,
    thinking: "medium",
    usage: { tokens: 50_000, contextWindow: 200_000, percent: 25 } as
      { tokens: number | null; contextWindow: number; percent: number | null } | undefined,
    entries: [] as unknown[],
    cwd: join(homedir(), "projects", "nix"),
    branch: "main",
  };
  const handlers = new Map<string, (...args: any[]) => void>();
  let factory: Factory | undefined;
  const ctx = {
    mode,
    get cwd() { return state.cwd; },
    get model() { return state.model; },
    getContextUsage: () => state.usage,
    sessionManager: { getEntries: () => state.entries, getBranch: () => [] },
    ui: { setFooter: (value: Factory) => { factory = value; } },
  };
  statusline({
    on: (name: string, handler: (...args: any[]) => void) => { handlers.set(name, handler); },
    getThinkingLevel: () => state.thinking,
  } as unknown as ExtensionAPI);
  const emit = (name: string) => handlers.get(name)!({}, ctx);
  function start() {
    emit("session_start");
    if (!factory) return undefined;
    let redraws = 0;
    let unsubscribes = 0;
    let branchListener: (() => void) | undefined;
    const footer = factory({ requestRender: () => redraws++ } as unknown as TUI, theme, {
      getGitBranch: () => state.branch,
      onBranchChange: (callback) => {
        branchListener = callback;
        return () => { unsubscribes++; branchListener = undefined; };
      },
    } as ReadonlyFooterDataProvider);
    return {
      footer,
      text: (width = 120) => plain(footer.render(width).at(-1)!),
      branchChange: () => branchListener?.(),
      redraws: () => redraws,
      unsubscribes: () => unsubscribes,
    };
  }
  return { state, emit, start };
}

function gruvboxTheme(accent?: string): Theme {
  const vars: Record<string, string> = { ...gruvbox.vars, yellow: accent ?? gruvbox.vars.yellow };
  const colors = Object.fromEntries(Object.entries(gruvbox.colors).map(([token, value]) => [token, vars[value] ?? value]));
  return new Theme(colors as never, colors as never, "truecolor", { name: gruvbox.name });
}

test("TUI-only ownership, live selection, replacement and disposal", () => {
  for (const mode of ["rpc", "json", "print"]) expect(harness(mode).start()).toBeUndefined();
  const h = harness();
  const first = h.start()!;
  h.state.model!.id = "other";
  h.state.thinking = "high";
  h.emit("model_select");
  h.emit("thinking_level_select");
  first.branchChange();
  expect(first.redraws()).toBe(3);
  expect(first.text()).toContain("other high");
  const second = h.start()!;
  first.footer.dispose?.();
  h.emit("model_select");
  expect(first.unsubscribes()).toBe(1);
  expect(first.redraws()).toBe(3);
  expect(second.redraws()).toBe(1);
  second.footer.dispose?.();
  h.emit("thinking_level_select");
  expect(second.unsubscribes()).toBe(1);
  expect(second.redraws()).toBe(1);
});

test("aligned metadata includes whole-session cost and honest context usage", () => {
  const h = harness();
  const home = homedir();
  const view = h.start()!;
  const paths: Array<[string, string]> = [
    [join(home, "projects", "nix"), "nix"],
    [join(home, "projects"), "~/projects"],
    [home, "~"],
    ["/tmp/outside", "/tmp/outside"],
    [join(home, "projects-other", "nix"), "~/projects-other/nix"],
  ];
  for (const [cwd, label] of paths) {
    h.state.cwd = cwd;
    expect(view.text()).toStartWith(`${label} │`);
  }
  h.state.cwd = join(home, "projects", "nix");
  expect(view.text()).toMatch(/^nix │ ⎇ main │ gpt-5 medium {2,}\$0\.000 │ ctx \[▮{3}▯{7}\] 50k\/200k 25%$/);
  expect(view.text()).not.toMatch(/—|[█░·]/);
  h.state.entries = [
    { type: "message", message: { role: "assistant", usage: usage(0.1) } },
    { type: "message", message: { role: "toolResult", usage: usage(0.2) } },
    ...["usage", "compaction", "branch_summary"].map((type) => ({ type, usage: usage(0.4) })),
  ];
  expect(view.text()).toMatch(/^nix │ ⎇ main │ gpt-5 medium {2,}\$1\.500 │ ctx \[▮{3}▯{7}\] 50k\/200k 25%$/);
  h.state.branch = "";
  expect(view.text()).toContain("⎇ —");
  for (const [tokens, percent, expected] of [
    [0, 0, "ctx [▯▯▯▯▯▯▯▯▯▯] 0/200k 0%"],
    [null, null, "ctx —"],
    [50_000, null, "ctx [    ?     ] 50k/200k ?"],
    [250_000, 125, "ctx [▮▮▮▮▮▮▮▮▮▮] 250k/200k 100%"],
  ] as const) {
    h.state.usage = { tokens, contextWindow: 200_000, percent };
    expect(view.text()).toEndWith(expected);
  }
  h.state.usage = undefined;
  h.state.model = undefined;
  expect(view.text()).toMatch(/no model.*ctx —$/);
});

test("narrow layouts shorten values without dropping fields and sanitize terminal controls", () => {
  const h = harness();
  const view = h.start()!;
  h.state.cwd = join(homedir(), "projects", "nix", "long-".repeat(20));
  h.state.branch = "branch".repeat(40);
  h.state.model!.id = "漢字 👩‍💻 e\u0301";
  for (const width of [0, 1, 16, 40, 80, 200]) {
    const lines = view.footer.render(width);
    expect(lines).toHaveLength(1);
    expect(visibleWidth(lines[0])).toBe(width);
    expect(plain(lines[0])).not.toMatch(/[\r\n\x1b]/);
    if (width >= 16) expect(plain(lines[0]).match(/│/g)).toHaveLength(3);
  }
  const narrow = view.text(80);
  expect(narrow).toStartWith("nix/");
  expect(narrow).toContain("│ ⎇ branch");
  expect(narrow).toContain("$0.000 │ ctx [▮▮▮▯▯▯▯▯▯▯] 50k/200k 25%");
  expect(view.text(60)).toEndWith("ctx [▮▮▮▯▯▯▯▯▯▯] 50k/200k 25%");
  expect(narrow).toContain("…");

  h.state.cwd = `${join(homedir(), "projects", "nix")}/\x1b[31mevil\x07`;
  h.state.model!.id = "model\x1b]0;title\x07id\x07";
  h.state.branch = "main\x07\x1b[38;5;99m";
  const raw = view.footer.render(120).at(-1)!;
  expect(plain(raw)).toMatch(/^nix\/evil │ ⎇ main │ modelid medium +\$0\.000 │ ctx \[▮{3}▯{7}\] 50k\/200k 25%/);
  expect(raw).not.toMatch(/title|\x07|\x1b\[38;5;99m|\x1b\[31m/);
});

test("context advisory colors preserve capacity scale and follow live theme changes", () => {
  let current = gruvboxTheme();
  const live = new Proxy({} as Theme, {
    get: (_target, prop) => (...args: any[]) => (current as any)[prop](...args),
  });
  const h = harness("tui", live);
  const view = h.start()!;
  const before = view.footer.render(120).at(-1)!;
  expect(before).toContain("\x1b[38;2;250;189;47m");
  current = gruvboxTheme("#010203");
  const after = view.footer.render(120).at(-1)!;
  expect(after).toContain("\x1b[38;2;1;2;3m");
  expect(after).not.toContain("\x1b[38;2;250;189;47m");
  expect(plain(after)).toBe(plain(before));
  for (const [tokens, contextWindow, color] of [
    [99_999, 1_000_000, "success"],
    [100_000, 1_000_000, "warning"],
    [199_999, 1_000_000, "warning"],
    [200_000, 1_000_000, "error"],
    [31_360, 64_000, "success"],
    [32_000, 64_000, "warning"],
    [50_560, 64_000, "warning"],
    [51_200, 64_000, "error"],
    [50_000, 1_000_000, "success"],
  ] as const) {
    const percent = tokens / contextWindow * 100;
    h.state.usage = { tokens, contextWindow, percent };
    const rendered = view.footer.render(120).at(-1)!;
    const filled = Math.round(Math.round(percent) / 10);
    expect(rendered).toContain(current.fg(color, "▮".repeat(filled)));
    expect(rendered).toContain(current.fg(color, `${Math.round(tokens / 1000)}k`));
    expect(rendered).toContain(current.fg(color, `${Math.round(percent)}%`));
    expect(rendered).toContain(current.fg("dim", contextWindow === 1_000_000 ? "/1.0M" : "/64k"));
    expect(plain(rendered)).toContain(`[${"▮".repeat(filled)}${"▯".repeat(10 - filled)}]`);
  }
  h.state.usage = { tokens: 200_000, contextWindow: 1_000_000, percent: null };
  expect(view.footer.render(120)[0]).toContain(current.fg("error", "200k"));
  expect(view.text()).toEndWith("ctx [    ?     ] 200k/1.0M ?");
  h.state.usage = { tokens: null, contextWindow: 1_000_000, percent: null };
  expect(view.footer.render(120)[0]).toContain(current.fg("muted", "—"));
  expect(view.text()).toEndWith("ctx —");
});
