import { expect, test } from "bun:test";
import { stripVTControlCharacters } from "node:util";
import {
  AssistantMessageComponent, CustomEditor, getMarkdownTheme, getSelectListTheme, initTheme, renderDiff, ToolExecutionComponent,
  type ExtensionAPI, type ExtensionContext, type MarkdownTransformer, type ToolRendererResolver,
} from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, getKeybindings, KeybindingsManager, Markdown, setKeybindings, TUI_KEYBINDINGS, visibleWidth, type TUI } from "@earendil-works/pi-tui";
import compact from "./index.ts";
import gruvbox from "../gruvbox.json";

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
function row(name: string, args: unknown) {
  return new ToolExecutionComponent(name, "test-id", args, { outputPad: 0, showImages: false },
    resolve(name, () => undefined), { requestRender() {} } as TUI, "/work");
}

test("summaries sanitize input, bound widths and keep counts aligned through completion and errors", () => {
  const custom = { renderShell: "self" as const };
  expect(resolve("custom", () => custom)).toBe(custom);
  const view = row("bash", { command: "echo 漢字👩‍💻e\u0301\x1b[31mred\x1b[0m\x1b]0;title\x07\x00\u202e " + "long-command ".repeat(30) });
  const preparing = view.render(48)[2];
  view.markExecutionStarted();
  expect(view.render(48)[2]).toBe(preparing);
  const restored = row("bash", { command: "true" });
  restored.updateResult(result("ok")); // First final result without execution start or duration.
  expect(text(restored)).toContain("■ bash true");
  view.updateResult(result("one\ntwo"));
  for (const width of [48, 300]) {
    const rendered = view.render(width);
    expect(rendered).toHaveLength(4);
    expect(visibleWidth(rendered[2])).toBe(width);
    expect(plain(rendered)[2]).toMatch(/^■ bash echo 漢字👩‍💻éred .* {2}2 lines$/);
    if (width === 300) expect(plain(rendered)[2]).toMatch(/ {180,}2 lines/); // Command preview stays capped.
    expect(rendered.join("\n")).not.toMatch(/title|\x1b\[31m|[\x00\u202e]/);
  }
  const error = "Permission denied\nsecond detail\nCommand exited with code 1";
  view.updateResult(result(error, undefined, true));
  expect(text(view)).toMatch(/■ bash Permission denied.*3 lines/);
  view.setExpanded(true);
  expect(text(view)).toContain(error);
});

test("native boxes retain expanded details and preview only confirmed structured diffs", () => {
  const code = "const first = 1;\nreturn first;";
  const script = row("codemode", { code });
  script.updateResult(result("output first\noutput last", {
    calls: [{ name: "read", args: '{"path":"x"}', status: "error", error: "missing file" }],
    truncation: { truncated: true }, fullOutputPath: "/tmp/full-output.txt",
  }));
  script.setExpanded(true);
  script.setOutputPad(1);
  for (const detail of [`code: ${code}`, "output first\noutput last", '[error] read {"path":"x"}',
    "missing file", "Output truncated by tool.", "Full output: /tmp/full-output.txt"]) expect(text(script)).toContain(detail);

  const edit = row("edit", { path: "file", edits: [{ oldText: "old", newText: "new" }] });
  const diff = "-2 const old = 1;\n+2 const next = 1;\n 3 context\n+4 " + "漢字👩‍💻é\x1b[31m\x00\u202e".repeat(600) + " END-DIFF";
  edit.updateResult(result("Successfully replaced 1 block.", { diff }));
  const collapsed = edit.render(48);
  expect(plain(collapsed)[2]).toMatch(/^■ edit file +\+2\/-1$/);
  expect(collapsed[3]).toContain(renderDiff(diff.split("\n").slice(0, 2).join("\n")).split("\n")[0]);
  expect(collapsed).toHaveLength(3 + 16 + 1 + 1); // Frame, bounded preview, hint, bottom.
  expect(plain(collapsed).at(-2)).toContain("more (ctrl+o expand)");
  expect(collapsed.join("\n")).not.toMatch(/END-DIFF|\x1b\[31m|[\x00\u202e]/);
  for (const [rendered, width] of [[script.render(48), 48], [collapsed, 48], [edit.render(16), 16]] as const) {
    const background = rendered[1].match(/^\x1b\[48;[\d;]+m/)![0];
    for (const line of rendered.slice(1)) {
      expect(visibleWidth(line)).toBe(width);
      expect(line).toStartWith(background);
      expect(line).toEndWith("\x1b[49m");
      expect(line.slice(0, -5)).not.toMatch(/\x1b\[(?:0|49)?m/);
    }
  }
  expect(text(edit, 16)).toContain("ctrl+o");
  expect(edit.handleMouse({ type: "click", button: "left", x: 3, y: 3, screenX: 3, screenY: 3,
    width: 48, height: collapsed.length, shift: false, alt: false, ctrl: false })?.handled).toBe(true);
  const full = text(edit);
  expect(full).toContain("Successfully replaced 1 block.");
  for (const detail of ["-2 const old = 1;", "END-DIFF"]) expect(full.split(detail)).toHaveLength(2);
  for (const [isError, isPartial] of [[true, false], [false, true]]) {
    edit.setExpanded(false);
    edit.updateResult(result("Unconfirmed", { diff: "+1 reported" }, isError), isPartial);
    expect(text(edit)).not.toMatch(/reported|\+1\/-0/);
    edit.setExpanded(true);
    expect(text(edit)).toContain("Unconfirmed/reported diff");
  }
  const other = row("codemode", { code: "return result;" });
  other.updateResult(result("done", { diff: "+1 structured" }));
  expect(text(other)).toContain("+1 structured");
  expect(plain(other.render(80))[2]).toContain("1 line"); // No invented edit counts.
  const write = row("write", { path: "file.ts", content: "const first = 1;" });
  write.updateResult(result("written"));
  expect(text(write)).not.toContain("const first = 1;");
  write.setExpanded(true);
  expect(text(write)).toContain("content: const first = 1;");
  expect(text(write)).toContain("written");
});

test("prompt markers preserve Markdown, editor input, ownership and TUI-only lifecycle", () => {
  const markdown = "```ts\nconst x = 1;\n```";
  const context = { messageType: "user" as const, isStreaming: false, availableWidth: 80 };
  const mdTheme = getMarkdownTheme();
  const source = transform(markdown, context);
  expect(source).toBe(`## ❯ You\n\n${markdown}`);
  expect(transform(markdown, { ...context, isStreaming: true })).toBe(source);
  for (const empty of ["", " \n"]) expect(transform(empty, context)).toBe(empty);
  const rendered = new Markdown(source, 1, 1, mdTheme).render(80);
  expect(rendered.join("\n")).toContain(mdTheme.heading(mdTheme.bold("❯ You")));
  expect(plain(rendered).filter((line) => line.trim()).slice(1)).toEqual(
    plain(new Markdown(markdown, 1, 0, mdTheme).render(80)).filter((line) => line.trim()),
  );
  for (const messageType of ["assistant", "assistant-thinking"] as const) {
    for (const isStreaming of [false, true]) expect(transform(markdown, { ...context, messageType, isStreaming })).toBe(markdown);
  }
  type EditorFactory = NonNullable<ReturnType<ExtensionContext["ui"]["getEditorComponent"]>>;
  let factory: EditorFactory | undefined;
  const labels: (string | undefined)[] = [];
  const ctx = { mode: "tui", ui: {
    setHiddenThinkingLabel: (label?: string) => { labels.push(label); },
    getEditorComponent: () => factory,
    setEditorComponent: (value: EditorFactory | undefined) => { factory = value; },
  } } as ExtensionContext;
  sessions.session_start({}, ctx);
  const theme = { borderColor: (text: string) => `\x1b[33m${text}\x1b[39m`, selectList: getSelectListTheme() };
  const editor = factory!({ terminal: { rows: 30 }, requestRender() {} } as TUI, theme, getKeybindings());
  if (!(editor instanceof CustomEditor)) throw new Error("expected native editor");
  expect(editor.embedWorkingStatus).toBe(false);
  editor.focused = true;
  editor.handleInput("hello");
  const line = editor.render(40)[1];
  expect(line).toStartWith(theme.borderColor("❯") + " hello");
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
  sessions.session_shutdown({}, ctx);
  expect(factory).toBe(other);
  factory = undefined;
  sessions.session_start({}, ctx);
  factory = other; // A replacement installed after ours must survive shutdown too.
  sessions.session_shutdown({}, ctx);
  expect(factory).toBe(other);
  expect(labels).toEqual(Array(3).fill("Thinking...")); // Reapplied at each start; no shutdown resets.
  for (const mode of ["rpc", "json", "print"]) {
    sessions.session_start({}, { mode } as ExtensionContext);
    sessions.session_shutdown({}, { mode } as ExtensionContext);
  }
});

test("collapsed thinking keeps an aligned label, native expansion and diagnostics", () => {
  let label: string | undefined;
  sessions.session_start({}, { mode: "tui", ui: {
    getEditorComponent: () => () => {},
    setHiddenThinkingLabel: (value: string) => { label = value; },
  } } as ExtensionContext);
  expect(label).toBe("Thinking...");
  expect(gruvbox.colors.thinkingText).toBe(gruvbox.colors.dim);
  type Message = NonNullable<ConstructorParameters<typeof AssistantMessageComponent>[0]>;
  const base: Message = {
    role: "assistant", content: [{ type: "thinking", thinking: "Original reasoning\n\n" + "Wrapped reasoning ".repeat(12), thinkingSignature: "signature" }],
    api: "anthropic-messages", provider: "anthropic", model: "test", stopReason: "stop", timestamp: 0,
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
  };
  const answer: Message["content"] = [{ type: "text", text: "Visible answer" }];
  for (const streaming of [false, true]) {
    for (const content of [base.content, [...base.content, ...answer]]) {
      const message = { ...base, content };
      const saved = structuredClone(message);
      const view = new AssistantMessageComponent(undefined, true, getMarkdownTheme(), label, 1, [transform]);
      view.updateContent(message, streaming);
      const collapsed = plain(view.render(80));
      expect(collapsed[1]).toStartWith(" Thinking...");
      const tool = row("read", { path: "file" });
      tool.setOutputPad(1);
      const statusColumn = plain(tool.render(80))[2].indexOf("■");
      expect(collapsed[1].indexOf("Thinking...")).toBe(statusColumn);
      expect(collapsed.map((line) => line.trim())).toEqual(
        content.length === 1 ? ["", "Thinking..."] : ["", "Thinking...", "", "Visible answer"],
      );
      expect(view.handleMouse({ type: "click", button: "left", x: 4, y: 1, screenX: 4, screenY: 1,
        width: 80, height: collapsed.length, shift: false, alt: false, ctrl: false })?.handled).toBe(true);
      expect(plain(view.render(80))[1].indexOf("Original reasoning")).toBe(statusColumn);
      for (const line of plain(view.render(80)).filter((line) => line.includes("reasoning"))) {
        expect(line.search(/\S/)).toBe(statusColumn);
      }
      view.setHideThinkingBlock(false);
      expect(plain(view.render(80))[1].indexOf("Original reasoning")).toBe(statusColumn);
      view.setHideThinkingBlock(true);
      expect(text(view)).toContain("Thinking...");
      expect(text(view)).not.toContain("Original reasoning");
      expect(message).toEqual(saved);
    }
  }
  for (const [stopReason, diagnostic] of [["error", "Error: provider failed"], ["aborted", "provider failed"],
    ["length", "Response was truncated before completion."]] as const) {
    const view = new AssistantMessageComponent({ ...base, content: [...base.content, ...answer], stopReason,
      errorMessage: "provider failed" }, true, getMarkdownTheme(), label);
    expect(text(view)).toContain("Visible answer");
    expect(text(view)).toContain(diagnostic);
    expect(text(view)).toContain("Thinking...");
    expect(text(view)).not.toContain("Original reasoning");
  }
});
