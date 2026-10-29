import { afterEach, expect, spyOn, test } from "bun:test";
import { stripVTControlCharacters } from "node:util";
import {
  initTheme, Theme, ToolExecutionComponent,
  type ExtensionAPI, type ToolRendererResolver,
} from "@earendil-works/pi-coding-agent";
import { visibleWidth, type TUI } from "@earendil-works/pi-tui";
import compact from "./index.ts";

let resolve: ToolRendererResolver;
// Supplying ONLY this API proves registration never touches execution/events.
compact({ registerToolRenderer: (resolver) => { resolve = resolver; } } as ExtensionAPI);
initTheme("dark", false);
afterEach(() => initTheme("dark", false));
const plain = (lines: string[]) => lines.map(stripVTControlCharacters);
const result = (text = "", details?: unknown, isError = false) => ({
  content: [{ type: "text", text }], details, isError,
});
function row(name: string, args: unknown = {}, outputPad = 0) {
  const forbidden = () => { throw new Error("original renderer invoked"); };
  return new ToolExecutionComponent(name, "test-id", args, { outputPad, showImages: false },
    resolve(name, () => ({ renderCall: forbidden, renderResult: forbidden })), { requestRender() {} } as TUI, "/work");
}
function header(component: ToolExecutionComponent, width = 80) {
  const lines = plain(component.render(width));
  expect(lines).toHaveLength(2); // Pi's separator + exactly one content row.
  expect(lines[0]).toBe("");
  return lines[1];
}

test("lifecycle and replay stay single-row, including first-final metadata without duration", () => {
  const view = row("read", { path: "/work/README.md", offset: 4, limit: 6 });
  expect(header(view)).toBe("[preparing] read README.md:4–9");
  view.setArgsComplete();
  expect(header(view)).toContain("[preparing]");
  view.markExecutionStarted();
  expect(header(view)).toContain("[running]");
  view.updateResult(result("one\ntwo"), true);
  expect(header(view)).toBe("[running] read README.md:4–9 · 2 lines");
  view.updateResult(result("one\ntwo\nthree"));
  expect(header(view)).toBe("[done] read README.md:4–9 · 3 lines");
  const replay = row("bash", { command: "true" });
  replay.updateResult(result("ok"));
  expect(header(replay)).toBe("[done] bash true · 1 line");
});

test("missing and invalid arguments are safe; unknown and MCP renderers pass through", () => {
  for (const args of [undefined, null, ["path"], { path: false }]) {
    const view = row("read", args);
    expect(header(view)).toBe("[preparing] read ");
    view.setExpanded(true);
    expect(() => view.render(80)).not.toThrow();
  }
  const custom = { renderShell: "self" as const };
  for (const name of ["custom", "mcp__docs_search"]) {
    expect(resolve(name, () => custom)).toBe(custom);
    expect(resolve(name, () => undefined)).toBeUndefined();
  }
});

test("expansion preserves multiline arguments, output and nested codemode errors without timers", () => {
  const timer = spyOn(globalThis, "setInterval");
  try {
    for (const [name, args, summary] of [
      ["bash", { command: "echo first\necho second", timeout: 17 }, "echo first"],
      ["write", { path: "file", content: "first line\nlast line" }, "file"],
      ["codemode", { code: "\n  \nconst first = 1;\nreturn first;" }, "const first = 1;"],
    ] as const) {
      const view = row(name, args);
      view.setArgsComplete();
      view.markExecutionStarted();
      view.updateResult(result("output first\noutput last", name === "codemode" ? {
        calls: [{ name: "read", args: '{"path":"x"}', status: "error", error: "missing file" }],
        truncation: { truncated: true }, fullOutputPath: "/tmp/full-output.txt",
      } : undefined), true);
      expect(header(view)).toBe(`[running] ${name} ${summary} · 2 lines`);
      view.setExpanded(true);
      const expanded = plain(view.render(120)).join("\n");
      for (const [key, value] of Object.entries(args)) expect(expanded).toContain(`${key}: ${value}`);
      expect(expanded).toContain("output first\noutput last");
      if (name === "codemode") {
        for (const text of ['[error] read {"path":"x"}', "missing file", "Output truncated by tool.", "Full output: /tmp/full-output.txt"]) {
          expect(expanded).toContain(text);
        }
      }
    }
    expect(timer).not.toHaveBeenCalled();
  } finally { timer.mockRestore(); }
});

test("compact errors remain visible before long arguments; expansion retains the full error", () => {
  const view = row("bash", { command: "very-long-command".repeat(20) });
  const error = "Permission denied\nsecond detail\nCommand exited with code 1";
  view.updateResult(result(error, undefined, true));
  expect(header(view)).toContain("[error] bash Permission denied");
  view.setExpanded(true);
  expect(plain(view.render(80)).join("\n")).toContain(error);
  const script = row("codemode", { code: "throw Error('bad')" });
  script.updateResult(result("Script failed\nOutput:\nScript error:\nbad value", undefined, true));
  expect(header(script)).toContain("[error] codemode bad value");
});

test("edit summaries expand to semantic diffs and redraw with the current theme", () => {
  const color = spyOn(Theme.prototype, "fg");
  try {
    const view = row("edit", { path: "/does/not/exist", edits: [{ oldText: "old", newText: "new" }] });
    view.setArgsComplete();
    view.updateResult(result("Successfully replaced 1 block.", { diff: " 1 context\n-2 old\n+2 new" }));
    expect(header(view)).toContain("+1/-1");
    view.setExpanded(true);
    const before = view.render(80);
    expect(plain(before).join("\n")).toContain("Successfully replaced 1 block.\n 1 context\n-2 old\n+2 new");
    for (const [token, text] of [["toolDiffContext", " 1 context"], ["toolDiffRemoved", "-2 old"], ["toolDiffAdded", "+2 new"]]) {
      expect(color).toHaveBeenCalledWith(token, text);
    }
    initTheme("light", false);
    view.invalidate();
    expect(view.render(80)).not.toEqual(before);
    expect(plain(view.render(80))).toEqual(plain(before));
  } finally { color.mockRestore(); }
});

test("terminal controls cannot inject header lines or expanded styling", () => {
  const payload = "safe\x1b[31mred\x1b[0m\x1b]0;title\x07\x1bPpayload\x1b\\\n\r\t\x00\x08next\u2028line\u202e";
  const view = row("read", { path: payload });
  expect(header(view)).toBe("[preparing] read safered next line");
  expect(header(row("read", { path: "safe\x1b]unterminated" }))).toBe("[preparing] read safe");
  view.updateResult(result(payload, undefined, true));
  expect(header(view)).toContain("[error] read safered");
  view.setExpanded(true);
  const rendered = view.render(80).join("\n");
  expect(rendered).not.toMatch(/\x1b(?:\[31m|\]0;|Ppayload)/);
  expect(stripVTControlCharacters(rendered)).not.toMatch(/title|payload|\x00|\x08|\x1b/);
});

test("Unicode, tiny widths, resizing and padding stay within bounds", () => {
  const view = row("bash", { command: "echo 漢字 👩‍💻 café e\u0301\nsecond" }, 4);
  view.updateResult(result("漢字 👩‍💻 café e\u0301\n" + "x".repeat(150)));
  expect(header(view)).toMatch(/^ {4}\[done\].* {4}$/);
  for (const [width, pad, expanded] of [[0, 4, false], [1, 100, true], [10, 1, true], [80, 0, false]] as const) {
    view.setOutputPad(pad);
    view.setExpanded(expanded);
    for (const line of view.render(width)) {
      expect(visibleWidth(line)).toBeLessThanOrEqual(width);
      expect(stripVTControlCharacters(line)).not.toMatch(/[\r\n\x1b]/);
    }
    if (!expanded) header(view, width);
  }
});
