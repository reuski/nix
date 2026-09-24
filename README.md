# reuski/nix

Personal NixOS, nix-darwin, and Home Manager flake.

- Evaluation needs SSH access to the private `reuski/juttu` input.
- Home Manager is embedded in the system configurations, so user profiles activate with `nixos-rebuild switch` / `darwin-rebuild switch`; there is no separate step.
- User-owned packages and config live in `modules/home-manager/`; system-wide apps, services, networking, users, and GC live in `modules/nixos/` or `modules/darwin/`.
- Flake-parts (with `inputs.import-tree ./modules`) discovers every `.nix` file except paths containing `/_`; `modules/hosts/<host>/_*.nix` are explicit private wiring imported only by their own host.

## Hosts

| Host | System | Role |
| --- | --- | --- |
| `hiisi` | NixOS / `x86_64-linux` | Niri laptop |
| `sampo` | NixOS / `x86_64-linux` | Plasma desktop and gaming |
| `shodan` | NixOS / `x86_64-linux` | Web VPS |
| `ukko` | NixOS / `x86_64-linux` | Home server |
| `abraxas` | nix-darwin / `aarch64-darwin` | MacBook |

Outputs: `nixosConfigurations.<host>`, `darwinConfigurations.abraxas`, and matching `checks.<system>.<class>-<host>`.

## Validate

```sh
nix fmt .
git diff --check
nix flake check --no-build --all-systems
python3 .github/scripts/check-sops-recipients.py
python3 .github/scripts/check-private-imports.py

nix build --no-link ".#checks.x86_64-linux.nixos-hiisi" --print-build-logs
nix build --no-link ".#checks.aarch64-darwin.darwin-abraxas" --print-build-logs
```

## Switch

```sh
HOST=hiisi
sudo nixos-rebuild switch \
  --flake "github:reuski/nix/main#$HOST" \
  --refresh --option tarball-ttl 0

HOST=abraxas
sudo darwin-rebuild switch \
  --flake "github:reuski/nix/main#$HOST" \
  --refresh --option tarball-ttl 0
```

## New installs

Set the target once, then follow one path:

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"
install -d -m 0700 "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"
```

Set that recipient in `.sops.yaml` (replace the host's existing `&<host>` anchor, or add one), rekey every `secrets/*.yaml` with an authorized key, then commit and push **before** installing from GitHub.

### NixOS: remote (`nixos-anywhere`)

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" --extra-files "$HOSTDIR" root@<target-ip>
```

`nixos-anywhere` applies the host `_disko.nix`; confirm the target disk first.

### NixOS: ISO / Disko

```sh
TARGET=root@<iso-ip>
scp -r "$KEYDIR" "$TARGET:/tmp/ssh"
ssh "$TARGET" "
  export NIX_CONFIG='experimental-features = nix-command flakes'
  nix run github:nix-community/disko/latest -- \\
    --mode destroy,format,mount --yes-wipe-all-disks --flake '$FLAKE'
  install -d -m 0700 /mnt/etc/ssh
  install -m 0600 /tmp/ssh/ssh_host_ed25519_key /mnt/etc/ssh/
  install -m 0644 /tmp/ssh/ssh_host_ed25519_key.pub /mnt/etc/ssh/
  nixos-install --flake '$FLAKE' --no-root-passwd --no-channel-copy
  reboot
"
```

`reboot` boots the installed system and drops the SSH session; `--yes-wipe-all-disks` is destructive, so confirm the host and disk before running.

### nix-darwin: bootstrap

```sh
HOST=abraxas
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
install -d -m 0700 "$HOSTDIR/sops/age"
nix shell nixpkgs#age -c age-keygen -o "$HOSTDIR/sops/age/keys.txt"
chmod 0600 "$HOSTDIR/sops/age/keys.txt"
nix shell nixpkgs#age -c age-keygen -y "$HOSTDIR/sops/age/keys.txt"
xcode-select --install
curl -L https://nixos.org/nix/install | sh -s -- --daemon
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

Replace `&abraxas` in `.sops.yaml` with that printed public key, rekey the secrets as described above with the admin key available, and commit and push. Then send the generated private key over an approved channel and copy it into place:

```sh
AGE_KEY="$HOME/Library/Application Support/sops/age/keys.txt"
install -d -m 0700 "$(dirname "$AGE_KEY")"
install -m 0600 <received-key-file> "$AGE_KEY"
sudo nix --extra-experimental-features "nix-command flakes" run \
  github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake "github:reuski/nix/main#abraxas" --refresh --option tarball-ttl 0
ls "$HOME/.config/sops-nix/secrets/ssh/id_ed25519"
```

## Secrets

```sh
sops secrets/<name>.yaml
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
```

Recipients live in `.sops.yaml`; keep `secrets/*.yaml` as ciphertext only.

## Operations

```sh
# ukko deploy and cache
ssh root@ukko systemctl status atticd.service attic-cache.service deploy.service
ssh root@ukko systemctl start deploy.service
ssh root@ukko journalctl -u deploy.service -n 80 --no-pager

# ukko restic backup
ssh root@ukko systemctl status restic-backups-ukko.timer restic-backups-ukko.service
ssh root@ukko systemctl start restic-backups-ukko.service
sudo restic-ukko snapshots
sudo restic-ukko stats latest
sudo restic-ukko check --read-data-subset=1/7

# shodan tailnet re-enroll and web restart
sudo tailscale up
sudo systemctl restart web-beebud web-wahuu-games caddy
```

## Backup restore

Install the matching SOPS configuration first; the sync replaces live service state.

```sh
RESTORE="$HOME/.local/state/reuski-nix/ukko/restore"
rm -rf "$RESTORE" && mkdir -p "$RESTORE"
sudo restic-ukko restore latest --target "$RESTORE"
ls "$RESTORE/var/lib"
```

```sh
sudo systemctl stop actual linkding vaultwarden jellyfin audiobookshelf \
  navidrome hass sonarr radarr lidarr prowlarr sabnzbd qbittorrent \
  maintainerr calibre-web tome degoog trek valheim restic-backups-ukko
sudo rsync -a "$RESTORE/var/" /var/
sudo systemctl daemon-reload
sudo systemctl start actual linkding vaultwarden jellyfin audiobookshelf \
  navidrome hass sonarr radarr lidarr prowlarr sabnzbd qbittorrent \
  maintainerr calibre-web tome degoog trek valheim
sudo systemctl --failed
sudo journalctl -b -p warning..alert --no-pager
sudo rm -rf "$RESTORE"
```
