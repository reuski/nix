# PLAN: ACME renewal + Jellyfin setup failures (2026-10-21)

Docs-only plan; read-only diagnostics were performed, with no live changes or
implementation. Only this file is authorized now; unit restarts, credential writes, and
non-read-only diagnostics need separate approval.

## Scope and preservation

- Host `ukko`/`home.reuski.dev`; at observation generation `i90hj`, switch exit 4
  reporting `acme-order-renew-home.reuski.dev` and `jellyfin-setup` failures.
- Do not touch backup work or existing diffs: `README.md`,
  `modules/home-manager/llama.nix`, `modules/hosts/sampo/default.nix`,
  `modules/hosts/ukko/_services.nix`, `modules/nixos/backup.nix`, `BACKUP_REVIEW.md`.
  Planned edit sites (`modules/hosts/ukko/_proxy.nix`, `modules/nixos/jellyfin.nix`)
  are clean; keep changes isolated.
- No migrations, broad abstractions, disabled checks, password/admin reset, Jellyfin DB
  deletion, or Cloudflare token rotation (no auth rejection observed).

## Read-only evidence

P1 ACME:
- `acme-order-renew-home.reuski.dev.service`: activating/auto-restart with
  `Result=exit-code`, `ExecMainStatus=11`; renewals 14:51:25–14:55:35 failed DNS-01
  for `home.reuski.dev` and `*.home.reuski.dev`.
- `127.0.0.1:53` did not return the expected TXT for
  `_acme-challenge.home.reuski.dev`. No token rejection in captured logs; challenge
  creation/cleanup entries present.
- `/var/lib/acme/home.reuski.dev/fullchain.pem`: Let's Encrypt YE2, notBefore
  2026-08-06 05:55:19 GMT, notAfter 2026-11-04 05:55:18 GMT (~14 days left on
  2026-10-21), still valid; inspect only. SANs include `actual.reuski.dev` via
  `extraDomainNames`, so several routes share this expiry.
- `/etc/resolv.conf` has only `nameserver 127.0.0.1`; `_dns.nix` rewrites
  `home.reuski.dev` and `*.home.reuski.dev` to `192.168.1.11`. Split DNS observed:
  local TXT query returned NOERROR/0 answers; `@1.1.1.1` and `@9.9.9.9` each returned
  2 TXT answers; local A query returned `192.168.1.11`.

P2 Jellyfin:
- `jellyfin.service` is active/running (`Result=success`, up since 2026-10-18
  04:33:56); `/System/Info/Public` reports 12.2.0 and `StartupWizardCompleted=true`.
  Package is 12.2; liveness does not prove playback or API auth.
- `jellyfin-setup.service`: oneshot, `RemainAfterExit=true`, `Restart=on-failure`,
  `RestartSec=10s`, `StartLimitBurst=5`/5min; final `start-limit-hit`,
  `ExecMainStatus=22`; HTTP 400/curl 22 across 14:44–14:45 retries.
- Server logs 14:44:51/14:45:02/14:45:12 show `POST /Users/AuthenticateByName`
  throwing `System.ArgumentNullException` for `request.App` in
  `SessionManager.AuthenticateNewSessionInternal`; this pins the first failing step to
  auth, not later configuration or libraries.
- Script sends `X-Emby-Authorization: MediaBrowser Client="nix", Device="nixos",
  DeviceId="nixos-jellyfin-setup", Version="1"` plus JSON `{Username,Pw}` via `jq`;
  wizard posts are skipped because it is already complete.

## P1 — ACME renewal (certificate expires 2026-11-04)

Confirmed: renewal fails at DNS-01 propagation validation, not Cloudflare API
authentication. Very likely cause (strong, not proven here): lego's recursive
propagation check uses system resolver `127.0.0.1`, where the AdGuard rewrite masks the
challenge TXT. AdGuard behavior was inferred from `_dns.nix`, live dig counts, and
`/etc/resolv.conf`; the AdGuard config/UI was not inspected.

Upstream semantics (pinned nixpkgs
`/nix/store/2g1ydkkflg5kl8hb1f8js0s0p9v4gl53-source`):
- `security.acme.certs.<name>.dnsResolver` is typed `nullOr str` (`acme/default.nix`
  ~line 822): host:port for recursive queries; default is system resolvers.
- When set, lego gets `--dns.resolvers` (~line 255). With default
  `dnsPropagationCheck=true` (~line 863), ANS/RNS checks stay enabled; disable flags
  appear only when the check is turned off. Do not disable the check.

Preferred minimal change (`modules/hosts/ukko/_proxy.nix`):
- Add `security.acme.certs.${config.proxy.domain}.dnsResolver = "1.1.1.1:53";` beside
  the existing `extraDomainNames` wiring, or in the `security.acme` block if merging
  with `modules/nixos/proxy.nix` requires it. No `_dns.nix` change, no global resolver
  change, no rewrite removal, no forced public DNS for other services.
- Do not inflate timeouts to mask the issue, and do not rotate the Cloudflare token.

Preconditions: confirm no `--dns.resolvers` is already present via `systemctl cat
acme-order-renew-home.reuski.dev.service` and the referenced script; choose the resolver
from read-only tests (`dig` against 1.1.1.1 and 9.9.9.9), record the choice and reason,
confirm reachability and DNSSEC acceptance, and keep propagation checking enabled.

Verification (after approval):
- `systemctl show -p ActiveState,SubState,Result,ExecMainStatus
  acme-order-renew-home.reuski.dev.service` shows success/exit 0.
- `sudo nix shell nixpkgs#openssl -c openssl x509 -in
  /var/lib/acme/home.reuski.dev/fullchain.pem -noout -issuer -dates
  -ext subjectAltName` (plain openssl is not on the server PATH). Require notAfter later
  than 2026-11-04 and SANs covering `home.reuski.dev`, `*.home.reuski.dev`,
  `actual.reuski.dev`.
- Confirm `caddy.service` reloaded and serves the new certificate; never paste challenge
  TXT values.
- Rate limits: Let's Encrypt limits duplicate certificates and failed validations per
  hostname/account. Trigger at most one manual renewal per attempt with approval; use
  staging if repeating; never a tight loop. Auto-restart already consumes attempts.

Rollback: remove the `dnsResolver` line and keep certificate/account directories; with
approval restart the ACME base unit or run one renewal to restore prior behavior. The
certificate remains valid until 2026-11-04, but watch the deadline.

Approval boundaries: `systemctl start/restart acme-order-renew-...` or base-unit
actions require `ACTION / COMMAND / REASON`; read-only `systemctl show/cat`,
`journalctl`, `dig`, and `curl` are allowed. Approval is also required before a second
manual renewal or any ACME account, provider, or Cloudflare credential change.

## P2 — Jellyfin setup (after P1; no TLS deadline risk)

Confirmed: deterministic HTTP 400 at the first authenticated call,
`POST /Users/AuthenticateByName`, with `request.App` null; wizard completion is not the
problem and server runs 12.2.0. The null `request.App` confirms a client/session
metadata failure, not necessarily a credential failure; stage ordering was not
inspected, so a bad password is unproven. Candidate cause, not confirmed: the 12.2
parser no longer populates `request.App` from this `X-Emby-Authorization` form. Do not
reset the password, recreate the admin, rerun the wizard, or delete data to test this.

Diagnosis before code change: verify pinned 12.2 upstream parser/controller behavior and
the running OpenAPI/auth requirements (`systemctl cat jellyfin.service`; source via
`nix build --no-link .#nixosConfigurations.ukko.config.services.jellyfin.package.src`;
public OpenAPI endpoint if exposed), and record exact evidence for the accepted header.
Inspect only: `journalctl -u jellyfin.service --since "2026-10-21 14:40" | grep -E
'AuthenticateByName|ArgumentNullException' | tail -20` and `systemctl show -p
NRestarts,ActiveState,SubState jellyfin-setup.service`.

Planned minimal change (only if upstream evidence confirms it):
- Send the standards-supported `Authorization: MediaBrowser Client=..., Device=...,
  DeviceId=..., Version=...` header (or the form the running parser accepts), with
  stable client/device/version metadata; keep `X-Emby-Authorization` only if required.
  No secrets in headers or logs.
- Minimally extend the curl helper to expose a stage label, HTTP status, and sanitized
  error, without `set -x`, bodies, headers, or tokens. Add bounded
  `--connect-timeout`/`--max-time` if needed so readiness is genuinely bounded. Do not
  enlarge UI provisioning scope.
- Keep `Restart=on-failure` and the bounded start limit; do not raise `StartLimitBurst`
  to hide a deterministic 400. Transient retry is fine once fixed.

Verification: setup succeeds; `NRestarts` stable; no new HTTP 400 entries; login returns
an access token internally (never printed); configuration passes; libraries are not
duplicated; a second run succeeds idempotently; playback smoke test if operator access
is available. Prefer retrying the setup unit over restarting the server.

Rollback: revert the auth/diagnostic change and restart only `jellyfin-setup` after
approval; leave the server, admin account, libraries, and database intact.

## P3 — ACME credential wiring audit (separate)

`_secrets.nix` uses `restartUnits = [ "acme-home.reuski.dev.service" ]` for the
Cloudflare env template, while the failed unit is `acme-order-renew-home.reuski.dev`.
Upstream names the base service `acme-<cert>.service` and the timer target
`acme-order-renew-<cert>.service`; the base unit only `Wants` the order-renew unit, so a
template restart may not re-run a failed/auto-restarting renewal. Candidate stale
wiring, not confirmed as this cause (no token rejection); audit separately.

## Non-goals and checks

- No backup changes, migration, or compatibility branches; no AdGuard rewrite removal
  or global public-DNS change; no propagation-check disablement, timeout inflation, or
  token rotation; no Jellyfin password reset, admin recreation, wizard reset, or DB
  deletion.
- Implementation checks (lead runs; not executed here): `nix fmt .`, `git diff
  --check`, `nix flake check --no-build --all-systems` (evaluation needs SSH to the
  private `reuski/juttu` input), plus Python/repo checks if scripts change.
