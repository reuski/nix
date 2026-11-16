import { expect, test } from "bun:test";
import { stripVTControlCharacters } from "node:util";
import {
  AssistantMessageComponent, CustomEditor, getMarkdownTheme, getSelectListTheme, initTheme, ToolExecutionComponent,
  type ExtensionAPI, type ExtensionContext, type MarkdownTransformer, type ToolRendererResolver,
} from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, getKeybindings, KeybindingsManager, setCapabilityOverrides, setKeybindings, TUI_KEYBINDINGS, visibleWidth, type TUI } from "@earendil-works/pi-tui";
import compact from "./index.ts";

let resolve: ToolRendererResolver;
let transform: MarkdownTransformer;
const sessions: Record<string, (event: unknown, ctx: ExtensionContext) => void> = {};
compact({
  registerToolRenderer: (resolver) => { resolve = resolver; },
  registerMarkdownTransformer: (transformer) => { transform = transformer; },
  on: (event, handler) => { sessions[event] = handler; },
} as ExtensionAPI);
initTheme("dark", false);
setKeybindings(new KeybindingsManager({ ...TUI_KEYBINDINGS, "app.tools.expand": { defaultKeys: "ctrl+o" } }));
const plain = (lines: string[]) => lines.map(stripVTControlCharacters);
const text = (view: { render(width: number): string[] }, width = 80) => plain(view.render(width)).map((line) => line.trim()).join("\n");
const result = (text: string, details?: unknown, isError = false) => ({ content: [{ type: "text", text }], details, isError });
function row(name: string, args: unknown, showImages = false) {
  return new ToolExecutionComponent(name, "test-id", args, { outputPad: 0, showImages },
    resolve(name, () => undefined), { requestRender() {} } as TUI, "/work");
}
const click = (view: ToolExecutionComponent, needle: string) => view.handleMouse({
  type: "click", button: "left", x: 3, y: plain(view.render(80)).findIndex((line) => line.includes(needle)),
  screenX: 3, screenY: 3, width: 80, height: view.render(80).length, shift: false, alt: false, ctrl: false,
});
const childRows = (view: ToolExecutionComponent) => plain(view.render(80)).filter((line) => /^ {2}[✓✗…⊘?] /.test(line));

test("summaries sanitize terminal controls, bound Unicode widths and retain error diagnostics", () => {
  const custom = { renderShell: "self" as const };
  expect(resolve("custom", () => custom)).toBe(custom);
  const view = row("bash", { command: "echo 漢字👩‍💻e\u0301\x1b[31mred\x1b[0m\x1b]0;title\x07\x00\u202e " + "long-command ".repeat(30) });
  view.updateResult(result("one\ntwo"));
  for (const width of [16, 48, 300]) {
    const rendered = view.render(width);
    expect(rendered).toHaveLength(4);
    expect(visibleWidth(rendered[2])).toBe(width);
    expect(rendered.join("\n")).not.toMatch(/title|\x1b\[31m|[\x00\u202e]/);
    if (width >= 48) expect(plain(rendered)[2]).toMatch(/^■ bash echo 漢字👩‍💻éred .* {2}2 lines$/);
  }
  const error = "Permission denied\nsecond detail\nCommand exited with code 1";
  view.updateResult(result(error, undefined, true));
  expect(text(view)).toMatch(/■ bash Permission denied.*3 lines/);
  view.setExpanded(true);
  expect(text(view)).toContain(error);
});

test("diff previews are bounded and confirmed; expansion retains output and recovery paths", () => {
  const edit = row("edit", { path: "file" });
  const diff = "-2 old\n+2 new\n" + "+3 漢字\n".repeat(30) + "+4 END-DIFF";
  edit.updateResult(result("written", { diff }));
  for (const width of [16, 48]) {
    const lines = edit.render(width);
    expect(lines).toHaveLength(21);
    expect(text(edit, width)).not.toContain("END-DIFF");
    expect(text(edit, width)).toContain("(ctrl+o)");
    const background = lines[1].match(/^\x1b\[48;[\d;]+m/)![0];
    for (const line of lines.slice(1)) {
      expect(visibleWidth(line)).toBe(width);
      expect(line).toStartWith(background);
      expect(line).toEndWith("\x1b[49m");
      expect(line.slice(0, -5)).not.toMatch(/\x1b\[(?:0|49)?m/);
    }
  }
  expect(text(edit)).toContain("+32/-1");
  const bindings = getKeybindings();
  setKeybindings(new KeybindingsManager({ ...TUI_KEYBINDINGS, "app.tools.expand": { defaultKeys: "ctrl+e" } }));
  try { expect(text(edit, 16)).toContain("(ctrl+e)"); }
  finally { setKeybindings(bindings); }
  edit.setExpanded(true);
  expect(text(edit)).toContain("written");
  expect(text(edit).split("END-DIFF")).toHaveLength(2);
  for (const [isError, isPartial] of [[true, false], [false, true]]) {
    edit.setExpanded(false);
    edit.updateResult(result("Unconfirmed", { diff: "+1 reported" }, isError), isPartial);
    expect(text(edit)).not.toMatch(/reported|\+1\/-0/);
    edit.setExpanded(true);
    expect(text(edit)).toContain("Unconfirmed/reported diff");
  }
  const script = row("codemode", { code: "SCRIPT" });
  script.updateResult(result("OUTPUT", { truncation: { truncated: true }, fullOutputPath: "/tmp/full.txt" }));
  script.setExpanded(true);
  for (const detail of ["code: SCRIPT", "OUTPUT", "Output truncated by tool.", "Full output: /tmp/full.txt"])
    expect(text(script)).toContain(detail);
});

test("codemode child state follows recorded indices; parent expansion resets overrides", () => {
  const view = row("codemode", { code: "SCRIPT" });
  const read = { name: "read", args: '{"path":"/work/a"}', status: "running" };
  const bash = { name: "bash", args: '{"command":"false"}', status: "running" };
  view.updateResult(result("OUTPUT", { calls: [null, read, bash] }), true);
  expect(click(view, "… read")?.handled).toBe(true);
  expect(text(view)).toContain(`args: ${read.args}`);
  expect(text(view)).not.toMatch(/code: SCRIPT|OUTPUT/);

  const calls = [
    { name: "ls", status: "ok" },
    { ...read, status: "error", error: "missing file", durationMs: 1500 },
    { ...bash, status: "cancelled" },
    { name: "\u001b[31m " },
    { name: "models.classify", args: "provider/model", status: "ok", durationMs: 999.6, cost: 0 },
    { name: "mystery", args: '{"foo":"bar"}\u001b[31m\u0000\u202e漢', status: "unknown", durationMs: -4, cost: -1 },
  ];
  view.updateResult(result("OUTPUT", { calls }));
  expect(text(view)).toContain("5 calls");
  expect(text(view)).toContain("… 1 earlier call (ctrl+o)");
  expect(childRows(view).map((line) => line.trim()[0])).toEqual(["✗", "⊘", "✓", "?"]);
  for (const detail of [`args: ${read.args}`, "error: missing file", "1.5s", "1.0s $0.00", 'mystery {"foo":"bar"}漢'])
    expect(text(view)).toContain(detail);
  expect(view.render(80).join("\n")).not.toMatch(/\x1b\[31m|\u0000|\u202e|-4ms|-\$1/);
  expect(click(view, "✗ read")?.handled).toBe(true);
  expect(text(view)).not.toContain("error: missing file");
  expect(click(view, "■ codemode")?.handled).toBe(true);
  expect(childRows(view)).toHaveLength(5);
  for (const detail of ["code: SCRIPT", "OUTPUT", "error: missing file"]) expect(text(view)).toContain(detail);
  expect(click(view, "✗ read")?.handled).toBe(true);
  expect(text(view)).not.toContain("error: missing file");
  view.setExpanded(false);
  expect(text(view)).not.toContain("args:");
  view.setExpanded(true);
  expect(text(view)).toContain("error: missing file");
});

test("codemode previews reserve duration at narrow widths and retain truncated arguments", () => {
  const command = "printf 漢字👩‍💻 ".repeat(40) + "END-COMMAND";
  const view = row("codemode", { code: "SCRIPT" });
  view.updateResult(result("", { calls: [
    { name: "bash", args: '{"command":"' + command, status: "ok", durationMs: 50, cost: 0.01 },
  ] }));
  for (const width of [16, 40, 200]) {
    const line = plain(view.render(width))[3];
    expect(visibleWidth(line)).toBe(width);
    expect(line).toMatch(/^ {2}✓ bash.* {2,}50ms/);
    expect(line).toEndWith(width >= 40 ? "50ms $0.01" : "50ms");
    expect(line).not.toContain("END-COMMAND");
    if (width === 200) expect(line).toMatch(/\.{3} {80,}50ms/);
  }
  view.setExpanded(true);
  expect(text(view, 200)).toContain("END-COMMAND");
});

test("hidden recorded errors stay visible after four successes without changing parent status", () => {
  const view = row("codemode", { code: "return 'caught';" });
  const calls = [
    { name: "bash", status: "error", error: "EARLIER-FAILURE" },
    ...["read", "grep", "find", "ls"].map((name) => ({ name, status: "ok" })),
  ];
  const output = result("caught", { calls });
  const saved = structuredClone(output);
  view.updateResult(output);
  const header = view.render(80)[2];
  expect(text(view)).toContain("✗ 1 recorded error; … 1 earlier call (ctrl+o)");
  expect(text(view)).not.toContain("EARLIER-FAILURE");
  expect(childRows(view)).toHaveLength(4);
  for (const width of [16, 80]) {
    expect(view.render(width).every((line) => visibleWidth(line) <= width)).toBe(true);
    expect(text(view, width)).toContain("✗ 1");
  }
  view.setExpanded(true);
  expect(text(view)).toContain("error: EARLIER-FAILURE");
  view.setExpanded(false);
  expect(output).toEqual(saved);
  view.updateResult(result("error in unchecked output", { calls: calls.map((call) => ({ ...call, status: "ok" })) }));
  expect(text(view)).not.toContain("recorded error");
  expect(view.render(80)[2]).toBe(header);
});

test("images use a fallback only when native rendering is unavailable or disabled", () => {
  const image = { type: "image" as const, data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX2kAAAAASUVORK5CYII=", mimeType: "image/png" };
  for (const [showImages, capability] of [[false, "kitty"], [true, null], [true, "kitty"]] as const) {
    setCapabilityOverrides({ images: capability });
    try {
      const view = row("codemode", {}, showImages);
      view.updateResult({ content: [image], details: {}, isError: false });
      view.setExpanded(true);
      const rendered = view.render(80).join("\n");
      expect(rendered.includes("[Image: [image/png] 1x1]")).toBe(!showImages || !capability);
      expect(rendered.includes("\x1b_G")).toBe(showImages && !!capability);
    } finally { setCapabilityOverrides({}); }
  }
});

test("prompt and thinking markers preserve native input, expansion and component ownership", () => {
  const markdown = "```ts\nconst x = 1;\n```";
  const context = { messageType: "user" as const, isStreaming: false, availableWidth: 80 };
  expect(transform(markdown, context)).toBe(`## ❯ You\n\n${markdown}`);
  expect(transform("", context)).toBe("");
  for (const messageType of ["assistant", "assistant-thinking"] as const)
    expect(transform(markdown, { ...context, messageType })).toBe(markdown);
  type EditorFactory = NonNullable<ReturnType<ExtensionContext["ui"]["getEditorComponent"]>>;
  let factory: EditorFactory | undefined;
  let label: string | undefined;
  const ctx = { mode: "tui", ui: {
    setHiddenThinkingLabel: (value?: string) => { label = value; },
    getEditorComponent: () => factory,
    setEditorComponent: (value: EditorFactory | undefined) => { factory = value; },
  } } as ExtensionContext;
  sessions.session_start({}, ctx);
  expect(label).toBe("Thinking...");
  const editor = factory!({ terminal: { rows: 30 }, requestRender() {} } as TUI,
    { borderColor: (text: string) => text, selectList: getSelectListTheme() }, getKeybindings());
  if (!(editor instanceof CustomEditor)) throw new Error("expected native editor");
  expect(editor.embedWorkingStatus).toBe(false);
  editor.focused = true;
  editor.handleInput("hello");
  const line = editor.render(40)[1];
  expect(line).toStartWith("❯ hello");
  expect(line).toContain(CURSOR_MARKER);
  expect(visibleWidth(line.split(CURSOR_MARKER)[0])).toBe(7);
  let submitted = "";
  editor.onSubmit = (value) => { submitted = value; };
  editor.handleInput("\r");
  expect(submitted).toBe("hello");
  sessions.session_shutdown({}, ctx);
  expect(factory).toBeUndefined();
  const other: EditorFactory = () => editor;
  factory = other;
  sessions.session_start({}, ctx);
  expect(factory).toBe(other);
  factory = undefined;
  sessions.session_start({}, ctx);
  factory = other;
  sessions.session_shutdown({}, ctx);
  expect(factory).toBe(other);
  for (const mode of ["rpc", "json", "print"]) sessions.session_start({}, { mode } as ExtensionContext);

  const message = new AssistantMessageComponent(undefined, true, getMarkdownTheme(), label);
  message.updateContent({
    role: "assistant", content: [{ type: "thinking", thinking: "Reasoning" }],
    api: "anthropic-messages", provider: "anthropic", model: "test", stopReason: "stop", timestamp: 0,
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
  }, false);
  expect(text(message)).toContain("Thinking...");
  expect(text(message)).not.toContain("Reasoning");
  message.setHideThinkingBlock(false);
  expect(text(message)).toContain("Reasoning");
});
