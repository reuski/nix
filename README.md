# reuski/nix

Personal NixOS, nix-darwin, and Home Manager flake. Home Manager is embedded
in the NixOS and nix-darwin configurations. Evaluation requires SSH access to
the private `reuski/juttu` input.

## Hosts

| Host | System | Role |
| --- | --- | --- |
| `hiisi` | NixOS / `x86_64-linux` | Niri laptop |
| `sampo` | NixOS / `x86_64-linux` | Plasma desktop and gaming |
| `shodan` | NixOS / `x86_64-linux` | Web VPS |
| `ukko` | NixOS / `x86_64-linux` | Home server |
| `abraxas` | nix-darwin / `aarch64-darwin` | MacBook |

Outputs: `nixosConfigurations.<host>`, `darwinConfigurations.abraxas`, and
matching `checks.<system>.<class>-<host>`.

## Verify

```sh
nix fmt .
git diff --check
nix flake check --no-build --all-systems
python3 .github/scripts/check-sops-recipients.py
python3 .github/scripts/check-private-imports.py
```

```sh
nix build --no-link ".#checks.x86_64-linux.nixos-hiisi" --print-build-logs
nix build --no-link ".#checks.aarch64-darwin.darwin-abraxas" --print-build-logs
```

CI evaluates and builds all hosts, checks SOPS recipients and private imports,
auto-formats Nix changes, and runs the daily update workflow.

## Switch

```sh
HOST=hiisi
sudo nixos-rebuild switch \
  --flake "github:reuski/nix/main#$HOST" \
  --refresh --option tarball-ttl 0
```

```sh
HOST=abraxas
sudo darwin-rebuild switch \
  --flake "github:reuski/nix/main#$HOST" \
  --refresh --option tarball-ttl 0
```

## Fresh NixOS install

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"

mkdir -p "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"
```

Replace the host recipient in `.sops.yaml`, then rekey all secrets:

```sh
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
```

Install with `nixos-anywhere`:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" --extra-files "$HOSTDIR" root@<target-ip>
```

ISO install:

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

## Fresh nix-darwin install

Generate and rekey the host key:

```sh
HOST=abraxas
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"

install -d -m 0700 "$HOSTDIR/sops/age"
nix shell nixpkgs#age -c age-keygen -o "$HOSTDIR/sops/age/keys.txt"
chmod 0600 "$HOSTDIR/sops/age/keys.txt"
nix shell nixpkgs#age -c age-keygen -y "$HOSTDIR/sops/age/keys.txt"
```

Replace `&abraxas` in `.sops.yaml`, then:

```sh
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
git commit -am "abraxas age key"
git push
```

Install Nix and receive the key:

```sh
xcode-select --install
curl -L https://nixos.org/nix/install | sh -s -- --daemon
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
install -d -m 0700 "$HOME/Library/Application Support/sops/age"
cd "$HOME/Library/Application Support/sops/age"
nix run nixpkgs#croc -- --yes <code>
chmod 0600 keys.txt
nix shell nixpkgs#age -c age-keygen -y keys.txt
```

Bootstrap and switch:

```sh
FLAKE="github:reuski/nix/main#abraxas"
sudo nix --extra-experimental-features "nix-command flakes" run \
  github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake "$FLAKE" --refresh --option tarball-ttl 0

sudo darwin-rebuild switch \
  --flake "$FLAKE" --refresh --option tarball-ttl 0
```

Check Home Manager secrets:

```sh
ls "$HOME/.config/sops-nix/secrets/ssh/id_ed25519"
cat "$HOME/Library/Logs/SopsNix/stderr"
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.sops-nix"
```

## Day-to-day operations

Deployment and cache on `ukko`:

```sh
ssh root@ukko systemctl status atticd.service attic-cache.service deploy.service
ssh root@ukko systemctl start deploy.service
ssh root@ukko journalctl -u deploy.service -n 80 --no-pager
```

Schedules:

- `deploy.timer`: 02:00; warms `sampo` and `hiisi`, deploys `shodan`
- `nixos-upgrade`: 03:00 workstations; 04:00--06:00 `ukko`
- `nix-darwin-upgrade`: 04:30 `abraxas`
- `homebrew-upgrade`: 05:00 `abraxas`

Cache key refresh:

```sh
sops updatekeys --yes secrets/ukko.yaml
ssh reuski@home.reuski.dev attic cache info ukko
```

Copy `Public Key` to `modules/nixos/nix.nix`.

`shodan`:

```sh
sudo tailscale up
sudo systemctl restart web-beebud web-wahuu-games caddy
```

## Secrets

```sh
sops secrets/<name>.yaml
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
```

SOPS recipients are defined in `.sops.yaml`. Keep `secrets/*.yaml` encrypted.
The admin key is exposed to the configured user through `SOPS_AGE_KEY_FILE`.

## Backups

`ukko` Restic backup:

```sh
ssh root@ukko systemctl status restic-backups-ukko.timer restic-backups-ukko.service
ssh root@ukko journalctl -u restic-backups-ukko.service -n 100 --no-pager
ssh root@ukko systemctl start restic-backups-ukko.service
sudo restic-ukko snapshots
sudo restic-ukko stats latest
sudo restic-ukko check --read-data-subset=1/7
```

Restore to staging:

```sh
HOST=ukko
RESTORE="$HOME/.local/state/reuski-nix/$HOST/restore"
rm -rf "$RESTORE"
mkdir -p "$RESTORE"
sudo restic-ukko restore latest --target "$RESTORE"
```

Restore service state after installing matching SOPS configuration:

```sh
sudo systemctl stop actual linkding vaultwarden jellyfin audiobookshelf \
  navidrome hass sonarr radarr lidarr prowlarr sabnzbd qbittorrent \
  maintainerr calibre-web tome degoog trek valheim restic-backups-ukko
sudo rsync -a "$RESTORE/var/" /var/
sudo systemctl daemon-reload
sudo systemctl start actual linkding vaultwarden jellyfin audiobookshelf \
  navidrome hass sonarr radarr lidarr prowlarr sabnzbd qbittorrent \
  maintainerr calibre-web tome degoog trek valheim
```

Validate and remove staging data:

```sh
sudo systemctl --failed
sudo journalctl -b -p warning..alert --no-pager
sudo rm -rf "$RESTORE"
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
