# Pi statusline

A single-row footer with Git branch, model/thinking level, and extension
statuses on the left, and session cost plus live context usage on the right.

```text
⎇ main │ openai/gpt-5 high │ running tests          $0.200 │ [█████░░░░░░░░░░░░░░░] 50k/200k 25%
```

The gauge starts at 8 interior cells and grows to 20 with spare width. As space
narrows, status excerpts shorten (capped at 40 columns), then provider, branch,
cost, gauge, and token counts drop before the model and percentage. The
percentage ends at the right edge; extra room stays between the two groups.
Unknown context shows `?`; status styling is preserved while other terminal
controls are removed. Cost covers the whole session, not just the current
branch.

`pi.nix` installs `index.ts` at `~/.pi/agent/extensions/statusline/index.ts`.
Replaces the built-in footer in TUI mode only; no dependencies or timers.
Tests use `bun:test` with Pi's dependencies available to the test runner.
