# reuski/nix

Personal dendritic flake. Agent rules: [AGENTS.md](AGENTS.md).

## Hosts

| Host      | Class      | System           | Role           |
| --------- | ---------- | ---------------- | -------------- |
| `hiisi`   | NixOS      | `x86_64-linux`   | Niri laptop    |
| `sampo`   | NixOS      | `x86_64-linux`   | Plasma desktop |
| `shodan`  | NixOS      | `x86_64-linux`   | VPS            |
| `ukko`    | NixOS      | `x86_64-linux`   | Home server    |
| `abraxas` | nix-darwin | `aarch64-darwin` | MacBook        |

## Graph

- `flake.nix`: `flake-parts` + `import-tree ./modules`.
- `modules/configurations/`: `configurations.{nixos,darwin}` -> flake outputs + checks.
- `modules/stacks/`: class composition only.
- `modules/{nixos,darwin,home-manager,generic}/`: reusable leaves.
- `modules/hosts/<host>/`: real hosts; `_*.nix` stays host-private.
- `modules/packages/`: overlays and custom packages.
- `secrets/*.yaml`: SOPS ciphertext.

## Commands

```sh
nix fmt
nix flake check
git diff --check
```

```sh
export SOPS_AGE_KEY="$(sops -d --extract '["admin_age_key"]' secrets/admin.yaml)"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
unset SOPS_AGE_KEY
```

CI:

- `.github/workflows/check.yml`: `nix fmt`, NixOS host builds, Darwin build/evaluation.
- `.github/workflows/update.yml`: daily `nix flake update`, `nix-update helium-browser`, PR automerge on green.

## Update Blockers

- Keep `nixpkgs` rolling; isolate the broken package.
- Prefer a fixed-rev, `flake = false` input for temporary package pins; no hidden fetchers.
- Scope pins to the host-private module that selects the broken package.
- Kernel pins: import only the pinned kernel, then use current `pkgs.linuxPackagesFor`.
- Do not pin NVIDIA, userspace, or whole package sets without a failing CI build proving they broke.
- Leave routine lock refresh to CI; update `flake.lock` locally only for input graph edits.
- Remove the pin after upstream builds green.

## Cache and Upgrades

`ukko` is the fleet builder, cache, and orchestrator.

- `cache.nix`: `atticd` at `127.0.0.1:8090`, tailnet-served `https://ukko.tail2fc4c2.ts.net:8090/ukko`. An `attic-cache` oneshot mints an ephemeral admin token and creates the `ukko` cache if absent, so `deploy` never pushes into a missing cache.
- `deploy.nix`: one `deploy` service+timer, ordered after `attic-cache`. `targets` (`shodan`) build, push, and activate over Tailscale SSH; `warm` (`sampo`, `hiisi`) build and push for self-upgrade pull.
- `nix.nix`: owns `nix.settings`. Declares only added caches (the `ukko` attic first on every host but `ukko`, then cachix endpoints); NixOS core appends `cache.nixos.org`. One URL for LAN and remote; Tailscale connects same-network peers directly.

Nightly cascade (Europe/Helsinki):

| Time            | Host         | Unit                                                            |
| --------------- | ------------ | --------------------------------------------------------------- |
| `02:00`         | ukko         | `deploy.timer`: warm, deploy `shodan`                           |
| `03:00`         | workstations | `nixos-upgrade`: pull cache; `persistent` catches morning boots |
| `04:00`–`06:00` | ukko         | `nixos-upgrade`: self, reboot window                            |

The cache is an optimization, never a hard dependency (`connect-timeout = 5` + fallback):

- Offline: fall back to `cache.nixos.org` + local build.
- `atticd` mints a new signing keypair on cache creation; the stale key in `nix.nix` is ignored by clients until updated below.

Health: heimdash `Cache` card; run failures via `systemctl --failed`.

Fresh `ukko` (`/var/lib/atticd` is not persisted). `attic-cache` recreates the `ukko` cache automatically on boot; only the public key needs harvesting once:

```sh
sops updatekeys --yes secrets/ukko.yaml
```

```sh
ssh reuski@home.reuski.dev attic cache info ukko   # Public Key -> nix.nix
```

## Backups

`nixos.backup`: off-site `restic` over an `rclone` remote. The provider lives in the remote, so switching clouds is `backup.repository` plus the rclone config. `ukko` targets `filen` (`rclone:filen:nixbackup/ukko`).

- Scope: `backup.paths` is the unreproducible state a fresh install loses; never media or the Attic cache.
- Encryption: `restic` client-side; the remote never sees plaintext.
- Secrets in `secrets/<host>.yaml`: `backup/restic-password` (the keystone — kept in encrypted git so a scratched host restores itself), `backup/rclone-conf`.
- Schedule: daily, retention `7d/4w/6m`. Failures POST to ntfy; success stamps `backup.stampPath` for the heimdash `Backup` card (age + freshness, red past 36h).

Add a host: import `nixos.backup`, set `backup.paths`, add the two secrets to `secrets/<host>.yaml`.

Provider config (Filen secret fields stay rclone-obscured; rerun after a Filen password change):

```sh
rclone config   # create the `filen` remote
rclone_conf="$(rclone config file | tail -n 1)"
export SOPS_AGE_KEY="$(sops -d --extract '["admin_age_key"]' secrets/admin.yaml)"
awk '/^\[filen\]$/ { keep = 1 } /^\[/ && $0 != "[filen]" { keep = 0 } keep' "$rclone_conf" \
  | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' \
  | sops set --value-stdin secrets/ukko.yaml '["backup"]["rclone-conf"]'
unset SOPS_AGE_KEY
```

Restore (run on the host; the wrapper carries repo, password, and rclone config):

```sh
ssh reuski@home.reuski.dev
sudo restic-ukko snapshots
sudo restic-ukko restore latest --target /            # all paths in place
sudo restic-ukko restore latest --target /tmp/r --include /var/lib/navidrome
```

## Secrets

- Backend: `sops-nix` + age.
- Recipients: host keys plus `admin`; see [`.sops.yaml`](.sops.yaml).
- NixOS host keys: `/etc/ssh/ssh_host_ed25519_key.pub` -> `ssh-to-age`.
- Darwin bootstrap key: `~/Library/Application Support/sops/age/keys.txt`.
- Cross-secret editing key: `secrets/admin.yaml` -> `admin_age_key`.
- `homeManager.secrets`: installs tooling, sets `sops.age.keyFile`, exports `SOPS_AGE_KEY_FILE` to the decrypted admin key.
- Env files: `sops.templates`.
- Defaults: root-owned, `0400`; declare only exceptions such as `restartUnits`.

Edit:

```sh
sops secrets/env.yaml
```

Rekey:

```sh
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
```

## NixOS Install

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"
```

```sh
mkdir -p "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"
```

Update `.sops.yaml`, then:

```sh
sops updatekeys --yes secrets/users.yaml
[ -f "secrets/$HOST.yaml" ] && sops updatekeys --yes "secrets/$HOST.yaml"
```

Install:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" --extra-files "$HOSTDIR" root@<target-ip>
```

ISO path:

```sh
TARGET=root@<iso-ip>
scp -r "$KEYDIR" "$TARGET:/tmp/ssh"
ssh "$TARGET" bash <<EOF
  export NIX_CONFIG='experimental-features = nix-command flakes'
  nix run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE"
  install -d -m 0700 /mnt/etc/ssh
  install -m 0600 /tmp/ssh/ssh_host_ed25519_key /mnt/etc/ssh/
  install -m 0644 /tmp/ssh/ssh_host_ed25519_key.pub /mnt/etc/ssh/
  nixos-install --flake "$FLAKE" --no-root-passwd --no-channel-copy
  reboot
EOF
```

## Darwin Install

```sh
HOST=abraxas
FLAKE="github:reuski/nix/main#$HOST"
```

```sh
xcode-select --install
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

```sh
install -d -m 0700 "$HOME/Library/Application Support/sops/age"
age-keygen -o "$HOME/Library/Application Support/sops/age/keys.txt"
chmod 0600 "$HOME/Library/Application Support/sops/age/keys.txt"
```

Update `.sops.yaml` with `&abraxas`, rekey `secrets/admin.yaml`, then:

```sh
nix run github:nix-darwin/nix-darwin -- switch --flake "$FLAKE"
```

## Host Post

`shodan`:

```sh
sudo tailscale up
sudo systemctl restart web-service-beebud web-service-wahuu-games caddy
```
