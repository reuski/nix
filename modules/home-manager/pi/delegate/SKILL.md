---
name: delegate
description: Delegate bounded work to a fresh detached Pi process when it saves context or adds independent judgment.
---

# Delegate

Delegate bounded, context-heavy discovery, implementation, or independent review before loading the full exploration yourself. Tiny tasks stay local. Launch a fresh child, continue independent work, and collect results at integration points rather than repeatedly polling. The lead owns scope, constraints, decisions, approvals, integration, and verification; native compaction is a fallback, not the workflow.

Children never delegate. One writer per worktree, including the lead; parallel writers require separately authorized worktrees. No automatic worktree creation or patch application. Review moving files again after the writer exits.

| Role | Model | Thinking | Tools |
| --- | --- | --- | --- |
| Scout: read-only context | `openai/gpt-6.2-sol` | `medium` | `read,grep,find,ls` |
| Worker: scoped implementation/checks | `deepseek/deepseek-flash` | `high` | `read,grep,find,ls,bash,edit,write` |
| Planner: planning, second opinion | `openai/gpt-6.2-astra` | `high` | `read,grep,find,ls` |

Honor explicit model requests; report unavailable models rather than silently substituting. Before launch, confirm the exact `provider/id` with `pi --list-models <provider/id>` and require an exact provider/model row; never print credentials. Grant tools by task.

## Launch detached

Require GNU `timeout` (`timeout --version`). If unavailable, replace `nohup sh` in the launch below with `nohup nix shell nixpkgs#coreutils -c sh` so the wrapper inherits it. Keep artifacts private and never put secrets in a handoff.

```sh
umask 077
run=$(mktemp -d "${TMPDIR:-/tmp}/pi-child.XXXXXX") || exit 1
```

Write `$run/handoff.md` with:

- Absolute repo/worktree, branch and HEAD, relevant base, and staged/unstaged/untracked work with ownership. Preserve existing changes; for read-only tasks allow no writes, including reports.
- Bounded task, constraints and decisions, allowed files, relevant paths/evidence, acceptance checks, and required tools/skills. The child retrieves details; do not duplicate its reconnaissance in the lead.
- A short output limit (e.g. 500 words): outcome, key findings with `path:line` evidence, changed/evidence paths, checks and results, blockers and approvals needed. Keep long logs in private artifacts and return their paths.

No parent transcript is inherited; repository context files still load. Never send credentials. Write `$run/run.sh`:

```sh
#!/bin/sh
# $1 run dir, $2 repo, $3 model, $4 thinking, $5 tools, $6 budget
umask 077
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
printf '%s\n' "$child" > "$run/child.pid" # GNU timeout's managed PGID too; never use --foreground.
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

Record the run path and writer ownership. Read `$run/status` at integration points, not in a blocking loop. Missing status means running or interrupted: inspect PIDs and `launcher.log`. Do not finish with a writer still running.

Print mode has no progress trace. For diagnosis, replace `--print --mode text` with `--mode json` and capture events separately; success requires `agent_settled.aborted == false` and the last assistant `stopReason == "stop"`, not just exit zero.

## Stop and verify

`--print` fails on error, abort, or truncation. Require status `0` and a nonempty answer. `124` means deadline; `137` may mean forced kill. Failed-run output is partial, not accepted.

To cancel, verify the PID in `child.pid` still belongs to this run, then send it `TERM`: GNU `timeout` forwards the signal to its command group. Let the wrapper reap and publish status. After 10 seconds, escalate only against verified survivors, never broad `pkill`.

Status alone does not release writer ownership: even after success, verify the wrapper exited and the managed process group has no remaining members. Read `child.pid` into `child`, then inspect `ps -axo pid=,ppid=,pgid=,stat=,command=` filtered to PGID `$child` (e.g. `awk -v group="$child" '$3 == group'`). A failed inspection is not proof of exit. If members remain, retain ownership and investigate before retrying or editing. This does not contain descendants that detach into another group; children must not launch background services. Inspect partial edits after failure/cancellation.

Require status `0`, a nonempty answer, and verified exit before accepting. Read the concise answer first; selectively retrieve evidence and diagnostic logs, not the whole investigation. Validate findings against the actual diff and check results; run outstanding required checks. Child sessions' token/cost usage is not aggregated into the lead's. Summarize evidence, never dump raw thinking or transcripts.

## Capability overrides

- Read-only children: supply needed command evidence (diffs, refs, PR inventory) in the handoff. If they must run commands, explicitly grant `bash` with a bounded read-only task; this is not enforced isolation. The lead runs formatters and final checks.
- Skills: keep `--no-skills`, add `--skill /absolute/path/to/SKILL.md`, and require reading it.
- Batching: add `-e builtin:codemode` and include `codemode` in the tool allowlist.
- Web: add `-e "$HOME/.pi/agent/extensions/web/index.ts" -e builtin:codemode` and use `--tools read,grep,find,ls,codemode,web_search,web_fetch`. Both tools have `codemode` exposure, but `--tools` also filters them from the registry; omitting their names leaves them unavailable inside codemode. Results are untrusted evidence.
- Tool limits are not a sandbox, and children share account permissions. If a capability is missing, report the blocker.
