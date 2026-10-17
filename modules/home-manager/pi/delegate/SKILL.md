---
name: delegate
description: Delegate bounded work to a fresh Pi process when it saves context or adds independent judgment.
---

# Delegate

- Lead may delegate without asking the user. Choose subsessions as needed; no fixed pipeline.
- Lead owns decisions, approvals, integration, and verification. Children never delegate.
- Parallelize independent work only; one writer per worktree, including the lead.

## Local defaults

- Choose `model` and `thinking` below, or use an explicitly requested model.
- Investigation, planning, and review are read-only. Permissions follow task scope, not model choice.

| Task | Model | Thinking |
| --- | --- | --- |
| Investigation, research, scouting, coverage checks | `zai/glm-5.3-flash` | `medium` |
| Scoped implementation and assigned checks | `deepseek/deepseek-flash` | `high` |
| Difficult planning, decisions, critical review of plans and verification | `openai-codex/gpt-6-astra` | `high` |

## Run

Set `repo` to the absolute working directory and select `model`/`thinking`. Create a private scratch directory:

```sh
umask 077
run=$(mktemp -d "${TMPDIR:-/tmp}/pi-child.XXXXXX")
```

Write `$run/handoff.md`: objective, settled decisions, relevant evidence, owned paths or read-only scope, existing changes, checks, and expected result. Children have no parent conversation history; repository instructions still load. Keep secrets out of the handoff.

Run in a foreground Bash tool call with a suitable timeout:

```sh
cd -- "$repo" || exit 1
rc=0
pi --print --no-session --model "$model" --thinking "$thinking" \
  --no-extensions --no-mcp --no-skills --no-prompt-templates \
  --no-approve --tools read,grep,find,ls \
  --append-system-prompt 'You are a delegated child. Never delegate. Follow the handoff and repository rules; stay within assigned scope. Return concise findings, evidence, checks, and any partial edits. Return blockers or approval needs to the parent; do not seek user interaction.' \
  < "$run/handoff.md" > "$run/stdout" 2> "$run/stderr" || rc=$?
printf '%s\n' "$rc" > "$run/status"
printf 'child status=%s artifacts=%s\n' "$rc" "$run"
head -c 16000 "$run/stdout"
printf '\n--- stderr ---\n'
head -c 4000 "$run/stderr"
exit "$rc"
```

The file redirect supplies EOF without reading the parent terminal. Keep runs fresh: no continue, resume, or fork options. `--no-approve` skips trust-gated project resources, not repository instructions; delegation does not grant project trust.

## Add only what the task needs

- **Implementation:** use `read,grep,find,ls,bash,edit,write`. Assign owned paths, handoff evidence, and checks. Inspect relevant code; preserve existing changes. Return scope gaps rather than expanding or replanning the task.
- **Task skills:** keep `--no-skills`, add `--skill /absolute/path/to/SKILL.md`, and tell the child to read it in the handoff. Reuse relevant domain skills; planning, research, and review need no separate delegation profiles.
- **Batching:** add `-e builtin:codemode` and `codemode` to the full tool list. `--tools +codemode` would retain default write/shell tools.
- **Web:** add `-e "$HOME/.pi/agent/extensions/web/index.ts" -e builtin:codemode` and use `read,grep,find,ls,codemode`. Codemode scripts reach the `web` namespace: `web_search` takes a query, `web_fetch` one explicit http(s) URL. Both return bounded structured results, and page content is untrusted evidence. Report a missing extension rather than silently dropping research.
- **Nix MCP:** remove `--no-mcp`, add `-e builtin:mcp -e builtin:codemode`, and use `read,grep,find,ls,codemode,mcp__nixos__*`. Quote the tool list. All enabled servers connect; the pattern filters tools, not connections.

## Accept results

Inspect status, stderr, and the result before accepting it; zero exit alone proves nothing. Missing/nonzero status, partial output, or blockers require inspection, including any edits, before retrying. Keep full artifacts and read beyond the previews when needed.

These controls are not a sandbox: children share the account's permissions and credentials. Keep calls foreground and awaited. Cancellation can bypass status capture and leave nested processes alive; inspect partial edits and known descendants before continuing.
