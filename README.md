# reuski/nix

Personal dendritic flake. Agent rules: [AGENTS.md](AGENTS.md).

## Hosts

| Host | Class | System | Role |
| --- | --- | --- | --- |
| `hiisi` | NixOS | `x86_64-linux` | Niri laptop |
| `sampo` | NixOS | `x86_64-linux` | Plasma desktop |
| `shodan` | NixOS | `x86_64-linux` | VPS |
| `ukko` | NixOS | `x86_64-linux` | Home server |
| `abraxas` | nix-darwin | `aarch64-darwin` | MacBook |

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

## Cache and Upgrades

`ukko` is the fleet builder, binary cache (`services.atticd`), and upgrade
orchestrator. No containers; everything native.

- `modules/nixos/cache.nix`: `atticd` on `127.0.0.1:8090`, served on the tailnet
  at `https://ukko.tail2fc4c2.ts.net:8090/ukko`. Public key
  `ukko:NjZT4Lc1JJvioCv4z6Qv8zDmX+v25+e2r/9qGjTzHkU=`.
- `modules/nixos/deploy.nix`: one `deploy` service+timer. `targets` (`shodan`)
  are built, pushed, and activated over Tailscale SSH; `warm` (`sampo`, `hiisi`)
  are built and pushed to the cache for self-upgrade pull.
- `modules/nixos/cachix.nix`: every host except `ukko` consumes the ukko
  substituter + public key.

Nightly cascade (Europe/Helsinki):

| Time | Unit | Action |
| --- | --- | --- |
| `02:00` | `deploy.timer` (ukko) | warm `sampo`/`hiisi`, deploy `shodan` |
| `03:00` | `nixos-upgrade` (workstations) | pull warm cache; `persistent`, so an off machine upgrades on its next morning boot |
| `04:00`–`06:00` | `nixos-upgrade` (ukko, `headless.nix`) | self-upgrade with reboot window |

The cache is an optimization, never a hard dependency (`connect-timeout = 5` +
substituter fallback):

- **ukko offline**: nix fails fast and falls back to `cache.nixos.org` + local
  build. Upgrades still succeed, only slower.
- **ukko replaced**: a new host has a new signing key, so the old public key in
  `cachix.nix` no longer matches and those substitutes are ignored (fallback as
  above). Recovery is the re-bootstrap below plus committing the new key.

Health: the `Cache` card on the heimdash dashboard turns red if `atticd` is
unreachable. Orchestrator run failures surface via `systemctl --failed` and
`systemctl status deploy.service` on ukko (`nixos-upgrade.service` on clients).

Fresh `ukko` re-bootstrap (`/var/lib/atticd` is not persisted, so the cache and
its signing key are recreated):

```sh
sops updatekeys --yes secrets/ukko.yaml   # from a workstation, after the new host key
```

```sh
atticd-atticadm make-token --sub bootstrap --validity 1h --pull '*' --push '*' --configure-cache '*'
atticadm() { atticd-atticadm "$@"; }
attic login local http://127.0.0.1:8090 <token>
attic cache create ukko
attic cache configure ukko --public
attic cache info ukko          # copy the public key
```

Put the new public key in `modules/nixos/cachix.nix`, commit, and rebuild the
clients. Workstations need no secret to consume the cache.

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
