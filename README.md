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
nix run nixpkgs#nix-update -- helium-browser --flake --url https://github.com/imputnet/helium-linux --override-filename modules/packages/helium.nix
nix flake check
git diff --check
```

## Updates

Rolling unstable; CI gates every change by building all hosts.

- `.github/workflows/flake-lock.yml` — daily `nix flake update` + `nix-update helium-browser`, auto-merges on green.
- `.github/workflows/nix.yml` — formats + builds hosts on PR/push.
- `system.autoUpgrade` — hosts pull `main#<host>` daily; servers reboot 04:00–06:00 on kernel change.

## Secrets

Admin age key (one-time):

```sh
age-keygen -o "$HOME/.config/sops/age/keys.txt" # public key → .sops.yaml
```

## NixOS

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"
```

### Onboard

```sh
mkdir -p "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"  # → .sops.yaml

sops updatekeys --yes secrets/users.yaml
sops updatekeys --yes "secrets/$HOST.yaml"
git add .sops.yaml secrets/users.yaml "secrets/$HOST.yaml"
git commit -m "onboard $HOST"
```

### nixos-anywhere

```sh
TARGET=root@<target-ip>

nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" \
  --extra-files "$HOSTDIR" \
  "$TARGET"
```

### ISO install

```sh
sudo -i
# nmcli device wifi connect "SSID" password "PASSWORD"
systemctl start sshd
passwd
ip addr
```

From admin host, push the host key and run install:

```sh
TARGET=root@<iso-ip>
scp -r "$KEYDIR" "$TARGET:/tmp/ssh"

ssh "$TARGET" bash <<EOF
  export NIX_CONFIG='experimental-features = nix-command flakes'
  nix run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE"
  install -d -m 0700 /mnt/etc/ssh
  install -m 0600 /tmp/ssh/ssh_host_ed25519_key     /mnt/etc/ssh/
  install -m 0644 /tmp/ssh/ssh_host_ed25519_key.pub /mnt/etc/ssh/
  nixos-install --flake "$FLAKE" --no-root-passwd --no-channel-copy
  reboot
EOF
```

### Post

```sh
systemctl status sops-install-secrets
ls /run/secrets
```

## nix-darwin

```sh
HOST=abraxas
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
```

### Onboard

On admin:

```sh
mkdir -p "$HOSTDIR"
age-keygen -o "$HOSTDIR/keys.txt"   # → .sops.yaml

sops updatekeys --yes secrets/users.yaml
sops updatekeys --yes "secrets/$HOST.yaml"
git add .sops.yaml secrets/users.yaml "secrets/$HOST.yaml"
git commit -m "onboard $HOST"
```

### Bootstrap

On the Mac:

```sh
xcode-select --install
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

install -d -m 0700 "$HOME/.config/sops/age"
scp <admin>:".local/state/reuski-nix/$HOST/keys.txt" "$HOME/.config/sops/age/keys.txt"
chmod 0600 "$HOME/.config/sops/age/keys.txt"

nix run github:nix-darwin/nix-darwin -- switch --flake "$FLAKE"
```

## Per-host post

### shodan

```sh
sudo tailscale up
sudo systemctl restart web-service-beebud web-service-wahuu-games caddy
```
