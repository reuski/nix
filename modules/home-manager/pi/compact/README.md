# Compact Pi tool rows

Single-row tool summaries with clear status, short arguments, and result counts.
Errors stay visible; Pi's existing expansion controls reveal full arguments,
returned output, edit diffs, and recorded codemode details.

- Covers `read`, `bash`, `edit`, `write`, `grep`, `find`, `ls`, `codemode`, and
  `tool_search`. Other tool renderers remain unchanged.
- Uses Pi's semantic theme tokens, including the selected `gruvbox.json` palette.
- Renderer-only: no dependencies, timers, UI patches, or changes to tool execution
  or model context.

**Wiring.** `pi.nix` installs only `index.ts` at
`~/.pi/agent/extensions/compact/index.ts`.

**Limits.** The single-row guarantee excludes Pi's separator and native images.
Expansion shows retained output, not content already truncated by a tool.
Interactive rendering is the target; HTML-export status may remain `running`.
