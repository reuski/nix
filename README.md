# reuski/nix

## Hosts

| Host      | Role    | Notes                  |
| --------- | ------- | ---------------------- |
| `hiisi`   | Wayland | Laptop, primary deploy |
| `shodan`  | Server  | VPS, web apps          |
| `ukko`    | Server  | Home server, wired LAN |
| `abraxas` | Mac     | MacBook, dev env       |

## Check

```sh
nix fmt
nix flake update
nix flake check
nix run .#update-custom
git diff --check
```

## Secrets

### Admin

```sh
age-keygen -o "$HOME/.config/sops/age/keys.txt"
age-keygen -y "$HOME/.config/sops/age/keys.txt"
# Add the public key to .sops.yaml recipients
```

### Password Hash

```sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
systemd-firstboot --root="$tmp" --prompt-root-password --force --welcome=no
chmod u+r "$tmp/etc/shadow"
awk -F: '$1 == "root" { print $2 }' "$tmp/etc/shadow"
```

## Install NixOS

### Host

```sh
HOST="hiisi"
FLAKE="github:reuski/nix/main#$HOST"
KEYDIR="$HOME/.local/state/reuski-nix/$HOST/etc/ssh"

mkdir -p "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"

$EDITOR .sops.yaml
sops updatekeys --yes secrets/users.yaml
sops updatekeys --yes "secrets/$HOST.yaml"
git add .sops.yaml secrets/users.yaml "secrets/$HOST.yaml"
git commit -m "onboard $HOST secrets"
```

### Boot

```sh
sudo -i
# nmcli device wifi connect "SSID" password "PASSWORD"
systemctl start sshd
passwd
ip addr show
```

### Copy

```sh
HOST="hiisi"
TARGET="root@<iso-ip>"
KEYDIR="$HOME/.local/state/reuski-nix/$HOST/etc/ssh"

scp -r "$KEYDIR" "$TARGET:/tmp/ssh"
```

### Install

```sh
HOST="hiisi"
FLAKE="github:reuski/nix/main#$HOST"
export NIX_CONFIG="experimental-features = nix-command flakes"

nix run github:nix-community/disko/latest -- --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE"

install -d -m 0700 /mnt/etc/ssh
install -m 0600 /tmp/ssh/ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key
install -m 0644 /tmp/ssh/ssh_host_ed25519_key.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub

nixos-install --flake "$FLAKE" --no-root-passwd --no-channel-copy
reboot
```

### nixos-anywhere

```sh
HOST="shodan"
TARGET="root@<target-ip>"
KEYDIR="$HOME/.local/state/reuski-nix/$HOST"
FLAKE="github:reuski/nix/main#$HOST"

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$KEYDIR" \
  --flake "$FLAKE" \
  "$TARGET"
```

## macOS

### Bootstrap

```sh
xcode-select --install
curl -sSfL https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

HOST="abraxas"
FLAKE="github:reuski/nix/main#$HOST"

install -d -m 0700 "$HOME/.config/sops/age"
scp "<admin-host>:.config/sops/age/keys.txt" "$HOME/.config/sops/age/keys.txt"

nix run github:nix-darwin/nix-darwin -- switch --flake "$FLAKE"
```

## Post

### NixOS

```sh
systemctl status sops-install-secrets.service
ls -la /run/secrets
```

### shodan

```sh
sudo tailscale up
sudo systemctl restart web-service-beebud web-service-wahuu-games caddy
```
