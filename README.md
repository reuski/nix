# reuski/nix

Personal NixOS, nix-darwin, and Home Manager flake. Agent contract: [AGENTS.md](AGENTS.md).

## Verify

```sh
nix fmt .
git diff --check
nix flake check --no-build --all-systems
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

CI: evaluate, host builds, format PRs, routine input/package update PRs.

## Hosts

| Host | Class | System | Role |
| --- | --- | --- | --- |
| `hiisi` | NixOS | `x86_64-linux` | Niri laptop |
| `sampo` | NixOS | `x86_64-linux` | Plasma desktop |
| `shodan` | NixOS | `x86_64-linux` | VPS |
| `ukko` | NixOS | `x86_64-linux` | Home server |
| `abraxas` | nix-darwin | `aarch64-darwin` | Macbook |

## Switch

NixOS:

```sh
HOST=hiisi
sudo nixos-rebuild switch \
  --flake "github:reuski/nix/main#$HOST" \
  --refresh --option tarball-ttl 0
```

nix-darwin:

```sh
HOST=abraxas
sudo darwin-rebuild switch \
  --flake "github:reuski/nix/main#$HOST" \
  --refresh --option tarball-ttl 0
```

## Install

Fresh installs only.

### NixOS

Generate host key material before install:

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"

mkdir -p "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"
```

Add the printed age key to [`.sops.yaml`](.sops.yaml), then rekey affected files:

```sh
sops updatekeys --yes secrets/users.yaml
[ -f "secrets/$HOST.yaml" ] && sops updatekeys --yes "secrets/$HOST.yaml"
```

Install with `nixos-anywhere`:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" --extra-files "$HOSTDIR" root@<target-ip>
```

Install from ISO:

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

### nix-darwin

Generate age key on a NixOS host:

```sh
HOST=abraxas
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"

install -d -m 0700 "$HOSTDIR/sops/age"
nix shell nixpkgs#age -c age-keygen -o "$HOSTDIR/sops/age/keys.txt"
chmod 0600 "$HOSTDIR/sops/age/keys.txt"
nix shell nixpkgs#age -c age-keygen -y "$HOSTDIR/sops/age/keys.txt"
```

Replace `&abraxas` in [`.sops.yaml`](.sops.yaml), rekey, commit, push:

```sh
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
git commit -am "abraxas age key"
git push
```

Send the key to the Mac:

```sh
nix run nixpkgs#croc -- send "$HOSTDIR/sops/age/keys.txt"
```

Fresh install on the Mac:

```sh
HOST=abraxas
FLAKE="github:reuski/nix/main#$HOST"

xcode-select --install
curl -L https://nixos.org/nix/install | sh -s -- --daemon
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix --version
```

Receive key material:

```sh
install -d -m 0700 "$HOME/Library/Application Support/sops/age"
cd "$HOME/Library/Application Support/sops/age"
nix run nixpkgs#croc -- --yes <code>
chmod 0600 keys.txt
nix shell nixpkgs#age -c age-keygen -y keys.txt
```

Bootstrap nix-darwin:

```sh
sudo nix --extra-experimental-features "nix-command flakes" run \
  github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake "$FLAKE" --refresh --option tarball-ttl 0
```

Post-install switch:

```sh
sudo darwin-rebuild switch \
  --flake "$FLAKE" --refresh --option tarball-ttl 0
```

Secrets launchd check:

```sh
ls "$HOME/.config/sops-nix/secrets/ssh/id_ed25519"
cat "$HOME/Library/Logs/SopsNix/stderr"
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.sops-nix"
```

## Fleet

| Unit | Schedule | Scope |
| --- | --- | --- |
| `atticd.service` | service | cache API at `127.0.0.1:8090` |
| `attic-cache.service` | boot | create public `ukko` cache |
| `deploy.timer` | `02:00` | warm `sampo`/`hiisi`, deploy `shodan` |
| `nixos-upgrade` | `03:00` | workstations |
| `nixos-upgrade` | `04:00-06:00` | `ukko` |
| `darwin-auto-switch` | `04:30` | `abraxas`, Homebrew activation |

```sh
ssh root@ukko systemctl status atticd.service attic-cache.service deploy.service
ssh root@ukko systemctl start deploy.service
ssh root@ukko journalctl -u deploy.service -n 80 --no-pager
```

Cache key refresh:

```sh
sops updatekeys --yes secrets/ukko.yaml
ssh reuski@home.reuski.dev attic cache info ukko
```

Copy `Public Key` to `modules/nixos/nix.nix`.

## Secrets

- Backend: `sops-nix` + age.
- Recipients: host keys plus `admin`; source of truth: [`.sops.yaml`](.sops.yaml).
- NixOS host age keys derive from `/etc/ssh/ssh_host_ed25519_key.pub` via `ssh-to-age`.
- Darwin age key: `~/Library/Application Support/sops/age/keys.txt`.
- `secrets/admin.yaml` `admin_age_key`: cross-host editing key.
- Admin key path: `/run/secrets/admin_age_key`; darwin: `~/.config/sops-nix/secrets/admin_age_key`.
- `homeManager.secrets`: installs tooling and exports `SOPS_AGE_KEY_FILE`; sets `sops.age.keyFile` on darwin only.
- Env files: `sops.templates`; default root-owned `0400`; declare only exceptions such as `restartUnits`.

Edit:

```sh
sops secrets/env.yaml
sops secrets/ukko.yaml
```

Add file:

```sh
$EDITOR .sops.yaml
sops secrets/<name>.yaml
```

Rotate value:

```sh
sops secrets/<file>.yaml
```

Rekey after recipient changes:

```sh
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
```

Rotate admin key: replace `&admin` in [`.sops.yaml`](.sops.yaml), then rekey all.

CI `evaluate` checks recipient sets against [`.sops.yaml`](.sops.yaml) with `.github/scripts/check-sops-recipients.py`.

## Backups

```sh
sudo restic-ukko snapshots
sudo restic-ukko restore latest --target /
sudo restic-ukko restore latest --target /tmp/r --include /var/lib/navidrome
```

Store the `rclone` `[filen]` config in `secrets/ukko.yaml`:

```sh
rclone config
rclone_conf="$(rclone config file | tail -n 1)"
export SOPS_AGE_KEY="$(sops -d --extract '["admin_age_key"]' secrets/admin.yaml)"
awk '/^\[filen\]$/ { keep = 1 } /^\[/ && $0 != "[filen]" { keep = 0 } keep' "$rclone_conf" \
  | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' \
  | sops set --value-stdin secrets/ukko.yaml '["backup"]["rclone-conf"]'
unset SOPS_AGE_KEY
```

## Host Notes

`abraxas`:

```sh
chsh -s /etc/profiles/per-user/reuski/bin/fish
```

```sh
initdb -D ~/.local/state/postgres --auth-local=peer --auth-host=scram-sha-256 --encoding=UTF8
pg_ctl -D ~/.local/state/postgres -l ~/.local/state/postgres/server.log start
createdb <name>
pg_ctl -D ~/.local/state/postgres stop
```

```sh
redis-server --dir ~/.local/state/redis --daemonize yes
redis-cli shutdown
```

`shodan`:

```sh
sudo tailscale up
sudo systemctl restart web-beebud web-wahuu-games caddy
```
