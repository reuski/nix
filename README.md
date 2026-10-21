# reuski/nix

Personal NixOS, nix-darwin, and Home Manager flake.

- Evaluation needs SSH access to the private `reuski/juttu` input.
- System switch includes Home Manager.
- Sources: [AGENTS.md](AGENTS.md) (layout and rules), [flake.nix](flake.nix) (inputs), [modules/hosts](modules/hosts) (host entrypoints), [.sops.yaml](.sops.yaml) (recipients), [.github/workflows](.github/workflows) (CI).

## Hosts

| Host      | System                        | Role                      |
| --------- | ----------------------------- | ------------------------- |
| `hiisi`   | NixOS / `x86_64-linux`        | Niri laptop               |
| `sampo`   | NixOS / `x86_64-linux`        | Plasma desktop and gaming |
| `shodan`  | NixOS / `x86_64-linux`        | Web VPS                   |
| `ukko`    | NixOS / `x86_64-linux`        | Home server               |
| `abraxas` | nix-darwin / `aarch64-darwin` | MacBook                   |

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

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"
install -d -m 0700 "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"
```

- Set the host age recipient in `.sops.yaml`; rekey secrets with an authorized key.
- Commit and push recipients and ciphertext before installing from GitHub.

### NixOS: remote (`nixos-anywhere`)

Confirm host `_disko.nix` target disk.

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" --extra-files "$HOSTDIR" "root@<target-ip>"
```

### NixOS: ISO / Disko

Destructive: confirm host and target disk; reboot disconnects SSH.

```sh
TARGET="root@<iso-ip>"
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

- Replace the `&abraxas` recipient in `.sops.yaml` with that printed public key.
- Rekey and push the ciphertext with an authorized key.
- Transfer the age key securely, then copy it into place:

```sh
AGE_KEY="$HOME/Library/Application Support/sops/age/keys.txt"
install -d -m 0700 "$(dirname "$AGE_KEY")"
install -m 0600 "<received-key-file>" "$AGE_KEY"
sudo nix --extra-experimental-features "nix-command flakes" run \
  github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake "github:reuski/nix/main#abraxas" --refresh --option tarball-ttl 0
ls "$HOME/.config/sops-nix/secrets/ssh/id_ed25519"
```

## Secrets

```sh
sops "secrets/<name>.yaml"
for file in secrets/*.yaml; do sops updatekeys --yes "$file"; done
```

Recipients live in `.sops.yaml`; keep `secrets/*.yaml` as ciphertext only.

## Operations

```sh
# ukko deploy and cache
ssh root@ukko systemctl status atticd.service attic-cache.service deploy.service
ssh root@ukko systemctl start deploy.service
ssh root@ukko journalctl -u deploy.service -n 80 --no-pager

# shodan tailnet re-enroll and web restart
sudo tailscale up
sudo systemctl restart web-beebud web-wahuu-games caddy
```

### ComfyUI

```sh
# sampo, http://localhost:8188
sudo systemctl start comfyui
sudo systemctl stop comfyui
```

Models: `/var/lib/comfyui/models/<type>/`

```sh
sudo install -o comfyui -g comfyui -Dm644 ./model.safetensors \
  /var/lib/comfyui/models/checkpoints/model.safetensors
```

Custom nodes: `/var/lib/comfyui/custom_nodes`

Outputs: `~/Pictures/ComfyUI/` (`qwen/` for the Qwen workflow)

```sh
# one-shot CUDA cache (no sudo); redundant once sampo activates the substituter
nix build --no-link \
  ".#nixosConfigurations.sampo.config.services.comfyui.package" \
  --option extra-substituters https://cache.nixos-cuda.org \
  --option extra-trusted-public-keys \
  cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=
```

## Backup and restore

### Operate

```sh
sudo systemctl status restic-backups-ukko.timer restic-backups-ukko-check.timer
sudo systemctl start restic-backups-ukko.service        # manual backup
sudo systemctl start restic-backups-ukko-check.service  # full data read
sudo restic-ukko snapshots --group-by host
sudo restic-ukko stats --mode raw-data
sudo restic-ukko forget --group-by host \
  --keep-within 1d --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --dry-run
```

```sh
sudo nix shell nixpkgs#rclone -c rclone --config /run/secrets/backup/rclone-conf \
  cleanup filen:
```

### Restore

```sh
SNAP='replace-with-snapshot-id'
sudo systemctl stop restic-backups-ukko.timer restic-backups-ukko-check.timer
sudo systemctl show restic-backups-ukko.service restic-backups-ukko-check.service \
  -p Id -p ActiveState -p SubState   # both inactive: timers do not stop jobs
RESTORE=$(mktemp -d /var/tmp/ukko-restore.XXXXXX)
sudo restic-ukko restore "$SNAP" --target "$RESTORE" --verify
```

```sh
# after the smoke test
sudo systemctl start restic-backups-ukko.timer restic-backups-ukko-check.timer
```
