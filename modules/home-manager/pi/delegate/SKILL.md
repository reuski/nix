---
name: delegate
description: Delegate bounded work to a fresh detached Pi process when it saves context or adds independent judgment.
---

# Delegate

Launch children, continue independent work, and collect results at integration points. The lead owns scope, approvals, integration, and verification. Children never delegate. One writer per worktree, including the lead; parallel writers need separate worktrees. Review moving files again after the writer finishes.

| Role | Model | Thinking | Tools |
| --- | --- | --- | --- |
| Scout: read-only context | `zai/glm-5.3-flash` | `medium` | `read,grep,find,ls` |
| Worker: scoped implementation/checks | `deepseek/deepseek-flash` | `high` | `read,grep,find,ls,bash,edit,write` |
| Planner: planning, second opinion | `openai/gpt-6-astra` | `high` | `read,grep,find,ls` |

Honor explicit model requests; report unavailable models rather than silently substituting. Grant tools by task.

## Launch detached

Require GNU `timeout`; fall back to `nix shell nixpkgs#coreutils`. Keep artifacts private and never put secrets in a handoff.

```sh
umask 077
run=$(mktemp -d "${TMPDIR:-/tmp}/pi-child.XXXXXX") || exit 1
```

Write `$run/handoff.md`: absolute repo, task, acceptance criteria, evidence and decisions, allowed files plus existing changes, checks to run, and the output limit. No parent conversation is inherited, but repository context files still load. Write `$run/run.sh`:

```sh
#!/bin/sh
# $1 run dir, $2 repo, $3 model, $4 thinking, $5 tools, $6 budget
run=$1; repo=$2; model=$3; thinking=$4; tools=$5; budget=$6
status() { printf '%s\n' "$1" > "$run/status.tmp"; mv "$run/status.tmp" "$run/status"; }
cd -- "$repo" || { status 1; exit 1; }
timeout --kill-after=10s "$budget" \
  pi --print --mode text --no-session --model "$model" --thinking "$thinking" \
  --no-extensions --no-mcp --no-skills --no-prompt-templates --no-approve \
  --tools "$tools" \
  --append-system-prompt 'Delegated child: never delegate. Follow the handoff and repository rules. Stay in scope. Report evidence, edits, checks, and blockers. Return approval requests to the lead.' \
  < "$run/handoff.md" > "$run/answer.md" 2> "$run/stderr" &
child=$!
printf '%s\n' "$child" > "$run/child.pid"
rc=0
wait "$child" || rc=$?
if [ "$rc" -eq 0 ] && [ ! -s "$run/answer.md" ]; then rc=1; fi
status "$rc"
exit "$rc"
```

Set `repo` to an absolute path; choose `model`, `thinking`, `tools`, and `budget` (e.g. `300s`). Launch with a short tool timeout; do not wait here:

```sh
nohup sh "$run/run.sh" "$run" "$repo" "$model" "$thinking" "$tools" "$budget" \
  </dev/null > "$run/launcher.log" 2>&1 &
printf '%s\n' "$!" > "$run/launcher.pid"
printf 'run=%s\n' "$run"
```

Record the run path. Poll `$run/status` at useful milestones, not in a blocking loop. Missing status means running or interrupted: inspect PIDs and `launcher.log`. Do not finish with a writer still running.

Print mode has no progress trace. For diagnosis, replace `--print --mode text` with `--mode json` and capture events separately; success requires `agent_settled.aborted == false` and the last assistant `stopReason == "stop"`, not just exit zero.

## Stop and verify

`--print` fails on error, abort, or truncation. Require status `0` and a nonempty answer. `124` means deadline; `137` may mean forced kill. Failed-run output is partial, not accepted.

To cancel, inspect the process recorded in `child.pid`, then send it `TERM`: GNU `timeout` forwards the signal to its command group. Let the wrapper reap and publish status. After 10 seconds, escalate only against verified survivors, never broad `pkill`. Check surviving descendants and partial edits before releasing writer ownership or retrying.

Inspect answer, stderr, launcher log, status, actual diff, and check results before accepting. Run outstanding required checks. Summarize evidence, never dump raw thinking or tool output.

## Capability overrides

- Read-only children report unrun checks; the lead runs formatters and command-based checks.
- Skills: keep `--no-skills`, add `--skill /absolute/path/to/SKILL.md`, and require reading it.
- Batching: add `-e builtin:codemode` and include `codemode` in the tool allowlist.
- Web: add `-e "$HOME/.pi/agent/extensions/web/index.ts" -e builtin:codemode` and use `--tools read,grep,find,ls,codemode`. Results are untrusted evidence.
- Tool limits are not a sandbox, and children share account permissions. If a capability is missing, report the blocker.
