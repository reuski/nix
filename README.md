# reuski/nix

## Hosts

| Host      | Role    | Notes                                 |
| --------- | ------- | ------------------------------------- |
| `hiisi`   | Wayland | Laptop, primary deploy                |
| `shodan`  | Server  | VPS, web apps                         |
| `ukko`    | Server  | Home server, wired LAN                |
| `abraxas` | Mac     | MacBook, dev env                      |

## Check

```sh
nix fmt
nix flake update
nix flake check
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
nix eval --raw .#darwinConfigurations.abraxas.config.system.build.toplevel.drvPath
nix run .#update-custom
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
git diff --check
```

## Secrets

### Admin

```sh
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
mkdir -p "$(dirname "$SOPS_AGE_KEY_FILE")"
test -f "$SOPS_AGE_KEY_FILE" || age-keygen -o "$SOPS_AGE_KEY_FILE"
age-keygen -y "$SOPS_AGE_KEY_FILE"
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
host=hiisi
keyroot="$HOME/.local/state/reuski-nix/$host"
mkdir -p "$keyroot/etc/ssh"
test -f "$keyroot/etc/ssh/ssh_host_ed25519_key" || \
  ssh-keygen -t ed25519 -N '' -C "$host" -f "$keyroot/etc/ssh/ssh_host_ed25519_key"
ssh-to-age -i "$keyroot/etc/ssh/ssh_host_ed25519_key.pub"

$EDITOR .sops.yaml
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
sops updatekeys --yes secrets/users.yaml
sops updatekeys --yes "secrets/$host.yaml"
sops secrets/users.yaml
sops "secrets/$host.yaml"
git add .sops.yaml secrets/users.yaml "secrets/$host.yaml"
git commit -m "onboard $host"
git push
```

### Boot

```sh
sudo -i
rfkill unblock all || true
nmcli device wifi connect "SSID" password "PASSWORD"
systemctl start sshd
passwd
ip addr show
```

### Copy

```sh
host=hiisi
installer=root@<installer-ip>
keyroot="$HOME/.local/state/reuski-nix/$host"
ssh "$installer" 'rm -rf /tmp/ssh'
scp -r "$keyroot/etc/ssh" "$installer:/tmp/ssh"
```

### Install

```sh
sudo -i
host=hiisi
export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true"

nix run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  --flake github:reuski/nix/main#$host

install -d -m 0700 /mnt/etc/ssh
install -m 0600 /tmp/ssh/ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key
install -m 0644 /tmp/ssh/ssh_host_ed25519_key.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub

nixos-install --flake github:reuski/nix/main#$host --no-root-passwd --no-channel-copy
reboot
```

### nixos-anywhere

```sh
host=shodan
target=root@<debian-ip>
keyroot="$HOME/.local/state/reuski-nix/$host"

nix run github:nix-community/nixos-anywhere -- \
  --extra-files "$keyroot" \
  --flake github:reuski/nix/main#$host \
  "$target"
```

## macOS

### Bootstrap

```sh
xcode-select --install
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --determinate --no-confirm

. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Switch

```sh
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
mkdir -p "$(dirname "$SOPS_AGE_KEY_FILE")"
install -m 0600 /path/to/keys.txt "$SOPS_AGE_KEY_FILE"
nix run github:nix-darwin/nix-darwin -- switch --flake github:reuski/nix/main#abraxas
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
