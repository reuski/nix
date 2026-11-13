# GitHub retrieval

Use the installed `gh` read-only with the host and source named in the request, not checkout defaults.

- Resolve issue URLs with `gh issue view`, repository lists with `gh issue list`, and cross-repository lists with `gh search issues`; no project is required.
- For Projects v2, resolve project membership and actual fields/options through `user(login:)` or `organization(login:)`. Disclose mappings from requested names and ask on ambiguity. Never infer priority from field-option or API return order.
- Respect list and search limits and check query errors and access gaps. `gh project item-list` returns 30 items by default; raise `--limit`, compare with the reported total, and never let a capped result look complete. Report partial or capped results and offer to work from a provided export.
- With `gh api graphql --paginate`, declare `$endCursor: String`, pass `after: $endCursor`, select `pageInfo { hasNextPage endCursor }`, and compare fetched counts with `totalCount`. Page each decision-relevant nested connection (field values, labels, assignees, linked pull requests, comments) with its own cursor. `--slurp` cannot combine with `--jq`; pipe pages to `jq` under `set -o pipefail`.
- Distinguish `Issue`, `PullRequest`, `DraftIssue`, `null` or unresolvable entries, and inaccessible items. Track open, closed, and archived state, and treat pull requests as readiness evidence rather than issues.
- Keep canonical node IDs or URLs, repository identity, title, status, labels, assignees, and state. Filter the complete membership by requested scope and statuses before hydrating bodies or comments.
- Expand only scoped ambiguous candidates and, for finalists, their dependencies, linked work, and relevant discussion, not every body or historical comment.
- Keep scratch responses in a private temporary directory: `umask 077` before `mktemp -d`, never predictable or shared paths. Print compact evidence instead of raw exports.
