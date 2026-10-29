# Compact Pi

Compact, themed tool summaries with right-aligned counts and native expansion.
Confirmed structured diffs preview up to 16 rows with Pi's word-change highlighting;
expansion reveals full retained arguments, output and diagnostics. Covers `read`,
`bash`, `edit`, `write`, `grep`, `find`, `ls`, `codemode`, and `tool_search`;
other renderers pass through unchanged.

- Uses Pi's semantic theme tokens and the existing gruvbox palette.
- Adds `❯ You` to user messages and `❯` to the editor without changing input geometry.
- Keeps native Working/retry/compaction status above the editor. Existing custom
  editors take precedence and retain their own status placement.
- Uses native output padding to align tool status prefixes, icon-free `Thinking...`,
  and expanded reasoning. Gruvbox's `dimGray` mutes both label and reasoning.
  Collapsed by default; click or use Ctrl+T to expand.
  The native row is unboxed: full-width shading needs upstream renderer support.

Display-only public APIs: no dependencies, extension timers, internal UI patches,
filesystem reads, or changes to tool execution, saved prompts, or model context.
Inspired by [pi-polish](https://github.com/Pringled/pi-extensions/tree/main/packages/pi-polish),
without its grouping, diff engine, or palettes.

**Wiring:** `pi.nix` installs only `index.ts` at
`~/.pi/agent/extensions/compact/index.ts`. Pi resets the thinking label on reload;
the extension reapplies it at TUI session start without resetting other overrides
on shutdown. Competing label overrides are last-writer-wins.

**Limits:** Images remain native; tool-truncated output cannot be recovered. Stdout
patches require expansion; nested codemode results and write before-images are not
inferred. Native minimum widths apply. Interactive rendering is the target;
HTML-export status colors may remain pending.
