# reuski/nix

Personal NixOS, nix-darwin, and Home Manager flake. Agent rules: [AGENTS.md](AGENTS.md).

## Commands

```sh
nix fmt .
nix flake check --no-build
nix eval .#checks.aarch64-darwin --apply 'builtins.mapAttrs (_: d: d.drvPath)'
git diff --check
```

```sh
HOST=hiisi
nix build --no-link ".#checks.x86_64-linux.nixos-$HOST" --print-build-logs
HOST=abraxas
nix build --no-link ".#checks.aarch64-darwin.darwin-$HOST" --print-build-logs
```

```sh
export SOPS_AGE_KEY="$(sops -d --extract '["admin_age_key"]' secrets/admin.yaml)"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
unset SOPS_AGE_KEY
```

CI: evaluate, host builds, format PRs, input/package update PRs.

## Targets

| Host      | Class      | System           | Role            |
| --------- | ---------- | ---------------- | --------------- |
| `hiisi`   | NixOS      | `x86_64-linux`   | Niri laptop     |
| `sampo`   | NixOS      | `x86_64-linux`   | Plasma desktop  |
| `shodan`  | NixOS      | `x86_64-linux`   | VPS             |
| `ukko`    | NixOS      | `x86_64-linux`   | Home server     |
| `abraxas` | nix-darwin | `aarch64-darwin` | Mac workstation |

## Switch

```sh
HOST=hiisi
sudo nixos-rebuild switch --flake ".#$HOST"
```

```sh
HOST=abraxas
darwin-rebuild switch --flake ".#$HOST"
```

## Fleet

| Unit                  | Schedule      | Scope                         |
| --------------------- | ------------- | ----------------------------- |
| `atticd.service`      | service       | cache API at `127.0.0.1:8090` |
| `attic-cache.service` | boot          | create public `ukko` cache    |
| `deploy.timer`        | `02:00`       | warm `sampo`/`hiisi`, deploy `shodan` |
| `nixos-upgrade`       | `03:00`       | workstations                  |
| `nixos-upgrade`       | `04:00-06:00` | `ukko`                        |

```sh
ssh root@ukko systemctl status atticd.service attic-cache.service deploy.service
ssh root@ukko systemctl start deploy.service
ssh root@ukko journalctl -u deploy.service -n 80 --no-pager
```

```sh
sops updatekeys --yes secrets/ukko.yaml
ssh reuski@home.reuski.dev attic cache info ukko
```

Copy `Public Key` to `modules/nixos/nix.nix`.

## Secrets

- Backend: `sops-nix` + age. Recipients: host keys plus `admin`; see [`.sops.yaml`](.sops.yaml).
- NixOS host keys derive from `/etc/ssh/ssh_host_ed25519_key.pub` via `ssh-to-age`; darwin uses `~/Library/Application Support/sops/age/keys.txt`.
- `secrets/admin.yaml` -> `admin_age_key` is the cross-host editing key; decrypted to `/run/secrets/admin_age_key` (darwin: `~/.config/sops-nix/secrets/admin_age_key`) and exported via `SOPS_AGE_KEY_FILE`.
- `homeManager.secrets` installs tooling and exports `SOPS_AGE_KEY_FILE`; sets `sops.age.keyFile` on darwin only (NixOS secrets are system-level).
- Env files: `sops.templates`. Defaults: root-owned, `0400`; declare only exceptions such as `restartUnits`.

Edit a value:

```sh
sops secrets/env.yaml
```

Add a key to an existing file:

```sh
sops secrets/ukko.yaml
```

Add a secret file: create `secrets/<name>.yaml`, add a matching `creation_rules` entry in [`.sops.yaml`](.sops.yaml), then `sops -e`.

Rotate a value (e.g. API key): `sops secrets/<file>.yaml`, edit, save; `restartUnits` applies it.

Rotate the admin key: generate a new age key, replace `&admin` in [`.sops.yaml`](.sops.yaml), then rekey all.

Rekey (after recipient changes in [`.sops.yaml`](.sops.yaml)):
```sh
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
```

CI (`.github/workflows/check.yml` `evaluate`) verifies each file's recipient set matches [`.sops.yaml`](.sops.yaml) keylessly via `.github/scripts/check-sops-recipients.py`; catches stale and over-scoped recipients on every `secrets/**` change.

## Backups

```sh
sudo restic-ukko snapshots
sudo restic-ukko restore latest --target /
sudo restic-ukko restore latest --target /tmp/r --include /var/lib/navidrome
```

```sh
rclone config
rclone_conf="$(rclone config file | tail -n 1)"
export SOPS_AGE_KEY="$(sops -d --extract '["admin_age_key"]' secrets/admin.yaml)"
awk '/^\[filen\]$/ { keep = 1 } /^\[/ && $0 != "[filen]" { keep = 0 } keep' "$rclone_conf" \
  | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' \
  | sops set --value-stdin secrets/ukko.yaml '["backup"]["rclone-conf"]'
unset SOPS_AGE_KEY
```

## Install

NixOS key material:

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"
mkdir -p "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"
```

Rekey:

```sh
sops updatekeys --yes secrets/users.yaml
[ -f "secrets/$HOST.yaml" ] && sops updatekeys --yes "secrets/$HOST.yaml"
```

NixOS:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" --extra-files "$HOSTDIR" root@<target-ip>
```

NixOS ISO:

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

Darwin:

```sh
HOST=abraxas
FLAKE="github:reuski/nix/main#$HOST"
xcode-select --install
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
install -d -m 0700 "$HOME/Library/Application Support/sops/age"
age-keygen -o "$HOME/Library/Application Support/sops/age/keys.txt"
chmod 0600 "$HOME/Library/Application Support/sops/age/keys.txt"
nix run github:nix-darwin/nix-darwin -- switch --flake "$FLAKE"
```

## Inputs

- Routine input refresh: CI only.
- Local `flake.lock` edits: input graph changes only.
- Broken package: keep `nixpkgs` rolling, isolate the package.
- Temporary pins: fixed-rev, `flake = false`, scoped to the selecting host-private module.
- Kernel pins: pinned kernel only, then current nixpkgs' `linuxPackagesFor`.
- No NVIDIA, userspace, or package-set pins without failing-build proof.

## Host Notes

`shodan`:

```sh
sudo tailscale up
sudo systemctl restart web-service-beebud web-service-wahuu-games caddy
```
