import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { stripVTControlCharacters } from "node:util";
import { Theme, type ExtensionAPI, type ReadonlyFooterDataProvider } from "@earendil-works/pi-coding-agent";
import { visibleWidth, type TUI } from "@earendil-works/pi-tui";
import statusline from "./index.ts";

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
    statuses: new Map<string, string>(),
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
      getExtensionStatuses: () => state.statuses,
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
  const json = JSON.parse(readFileSync(new URL("../gruvbox.json", import.meta.url), "utf8"));
  if (accent) json.vars.yellow = accent;
  const colors = Object.fromEntries(Object.entries(json.colors).map(([token, value]) => [
    token, typeof value === "string" && value in json.vars ? json.vars[value] : value,
  ]));
  return new Theme(colors as never, colors as never, "truecolor", { name: json.name });
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
    [join(home, "projects", "nix", "subdir"), "nix/subdir"],
    [join(home, "projects"), "~/projects"],
    [home, "~"],
    [join(home, "other"), "~/other"],
    ["/tmp/outside", "/tmp/outside"],
    [join(home, "projects-other", "nix"), "~/projects-other/nix"],
  ];
  for (const [cwd, label] of paths) {
    h.state.cwd = cwd;
    expect(view.text()).toStartWith(`${label} │`);
  }
  h.state.cwd = join(home, "projects", "nix");
  expect(view.text()).toStartWith("nix │ ⎇ main │ openai/gpt-5 medium │ —");
  expect(view.text()).toMatch(/│ — +\$0\.000 │/);

  h.state.statuses.set("job", "running tests");
  h.state.entries = [
    { type: "message", message: { role: "assistant", usage: usage(0.1) } },
    { type: "message", message: { role: "toolResult", usage: usage(0.2) } },
    ...["usage", "compaction", "branch_summary"].map((type) => ({ type, usage: usage(0.4) })),
  ];
  expect(view.text()).toMatch(/^nix │ ⎇ main │ openai\/gpt-5 medium │ running tests {2,}\$1\.500 │ \[[█░]+\] 50k\/200k 25%$/);
  h.state.branch = "feature";
  expect(view.text()).toMatch(/^nix │ ⎇ feature.*\$1\.500/);
  h.state.branch = "";
  expect(view.text()).toContain("⎇ —");
  h.state.branch = "feature";
  h.state.usage = { tokens: null, contextWindow: 200_000, percent: null };
  expect(view.text()).toEndWith("?/200k");
  expect(view.text()).not.toMatch(/0%|[█░]/);
  h.state.usage = { tokens: 250_000, contextWindow: 200_000, percent: 125 };
  expect(view.text()).toContain("[████████████████████] 250k/200k 100%");
  h.state.usage = undefined;
  h.state.model = undefined;
  expect(view.text()).toMatch(/no model.*\?$/);
});

test("adaptive layout preserves core content, isolates styling and bounds Unicode", () => {
  const h = harness();
  const view = h.start()!;
  const gaugeCells = (width: number) => view.text(width).match(/\[([█░]+)\]/)![1].length;
  expect(gaugeCells(50)).toBe(8);
  expect(gaugeCells(200)).toBe(20);
  expect(view.text(20)).toMatch(/^gpt-5 medium {2,}25%$/);

  h.state.cwd = join(homedir(), "projects", "nix", "long-".repeat(20));
  h.state.branch = "branch".repeat(40);
  h.state.statuses.set("job", `running tests \x1b[1;7;31m${"x".repeat(200)}`);
  const raw = view.footer.render(80).at(-1)!;
  expect(plain(raw)).toMatch(/^gpt-5 medium │ running.*25%$/);
  expect(plain(raw)).not.toContain("long-");
  const excerpt = plain(raw).split(" │ ")[1].split("[")[0].trimEnd();
  expect(visibleWidth(excerpt)).toBeLessThanOrEqual(40);
  expect(raw).toMatch(/…\x1b\[0m {2,}\$0\.000 │ \[/);

  h.state.model!.id = "漢字 👩‍💻 e\u0301";
  for (const width of [0, 1, 20, 80, 200]) {
    const lines = view.footer.render(width);
    expect(lines).toHaveLength(2);
    expect(lines[0]).toBe("");
    expect(visibleWidth(lines[1])).toBe(width);
    expect(plain(lines[1])).not.toMatch(/[\r\n\x1b]/);
    if (width >= 3) expect(plain(lines[1])).toEndWith("25%");
  }
});

test("terminal controls are stripped while status SGR stays isolated", () => {
  const h = harness();
  h.state.cwd = `${join(homedir(), "projects", "nix")}/\x1b[31mevil\x07`;
  h.state.model!.id = "model\x1b]0;title\x07id\x07";
  h.state.branch = "main\x07\x1b[38;5;99m";
  h.state.statuses.set("b", "b\x1b[31mRED\x1b[0m\nnext\x07");
  h.state.statuses.set("a", "a\x1b[32mGREEN\x1bPpayload\x1b\\");
  h.state.statuses.set("empty", "\x1b[33m");
  h.state.statuses.set("unterminated", "\x1b]0;hidden");
  const view = h.start()!;
  const raw = view.footer.render(120).at(-1)!;
  expect(plain(raw)).toMatch(/^nix\/evil │ ⎇ main.*modelid.*aGREEN.*bRED next/);
  expect(raw).not.toMatch(/payload|title|hidden|\x07|\x1b\[38;5;99m/);
  expect(raw).toContain("\x1b[32mGREEN\x1b[0m");
  expect(raw).toContain("\x1b[31mRED\x1b[0m");
  h.state.statuses = new Map([["blank", ""], ["sgr", "\x1b[33m"], ["space", "\x1b[33m\n\x1b[0m"]]);
  const quiet = view.footer.render(120).at(-1)!;
  expect(plain(quiet).match(/—/g)).toHaveLength(1);
  expect(plain(quiet)).toMatch(/modelid medium │ — +\$0\.000 │/);
  expect(quiet).not.toContain("\x1b[33m");
});

test("Gruvbox semantic colors follow live theme changes", () => {
  let current = gruvboxTheme();
  const live = new Proxy({} as Theme, {
    get: (_target, prop) => (...args: any[]) => (current as any)[prop](...args),
  });
  const view = harness("tui", live).start()!;
  const before = view.footer.render(120).at(-1)!;
  expect(before).toContain("\x1b[38;2;250;189;47m");
  current = gruvboxTheme("#010203");
  const after = view.footer.render(120).at(-1)!;
  expect(after).toContain("\x1b[38;2;1;2;3m");
  expect(after).not.toContain("\x1b[38;2;250;189;47m");
  expect(plain(after)).toBe(plain(before));
});
