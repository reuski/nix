---
name: simplify
description: Simplify an implemented feature or fix while preserving required behavior. Use when asked to iterate on an implementation, trim a branch diff, remove unnecessary complexity, or consolidate tests; applies code changes rather than only reviewing.
---

# Simplify

Usage: `/skill:simplify [scope] [base-ref]`

Edit code; this is not a review. The best change is often none: stop when no evidenced problem remains.

## Review

- Read the repository instructions and check `git status --short` and the current branch.
- Take the base from the request, else the related PR target, else the verified repository default branch, never the tracking branch. Ask if unclear.
- Review the whole branch against that merge-base, including relevant committed, staged, unstaged, and untracked work. Preserve unrelated dirty work.
- Confirm the intent before editing; ask if it is unclear.
- Read the full diff and trace behavior through callers, configuration, tests, and neighboring code. Look for dead branches, redundant validation, duplicated helpers, and fallbacks the callers make unnecessary. Prefer existing project logic over new code.
- Start each invocation with a fresh read-only review through the existing delegate skill. Hand over the intent, base/head, and diff evidence with no prior conclusions, and ask only for concrete `path:line` evidence and a simpler proposal. Validate each finding against the code and discard unproven ones.

## Trim

- Plan one bounded, evidence-based change at a time, stating the behavior it preserves. Preserve required behavior, interfaces, and error handling. Remove a fallback only when evidence shows it is unreachable or redundant with existing handling.
- Reuse local logic; add no abstraction or dependency justified only by deduplication. No cleanup outside the branch.
- Keep unique critical and regression coverage; consolidate overlapping cases only when the remaining test asserts the same distinctive behavior. Never target a line count.

## Iterate

- Rerun the relevant project checks, inspect the final full diff, and repeat while evidenced improvements remain. Stop when no actionable improvements remain.
- Finish in chat with the outcome, changed files, checks, and limits. Write no report artifact.
