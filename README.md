# reuski/nix

Dendritic flake (flake-parts + import-tree) for all personal systems. Structure and module rules: [AGENTS.md](AGENTS.md).

## Hosts

| Host      | Stack     | System           | Notes       |
| --------- | --------- | ---------------- | ----------- |
| `sampo`   | `desktop` | `x86_64-linux`   | Desktop     |
| `hiisi`   | `laptop`  | `x86_64-linux`   | Laptop      |
| `ukko`    | `server`  | `x86_64-linux`   | Home server |
| `shodan`  | `server`  | `x86_64-linux`   | VPS         |
| `abraxas` | `mac`     | `aarch64-darwin` | MacBook     |

## Validate

```sh
nix fmt && nix flake check   # check builds every host toplevel
git diff --check
```

CI (`.github/workflows/nix.yml`) runs the same on every PR/push.

## Updates

Rolling unstable; every input `follows` nixpkgs except cache-backed GUI inputs. CI gates each change.

- `flake-lock.yml` — daily `nix flake update` + `nix-update helium-browser`, auto-merges on green.
- `nix.yml` — formats, builds NixOS hosts, evaluates darwin on PR/push.
- `system.autoUpgrade` — hosts pull `main#<host>` daily; servers reboot 04:00–06:00 on kernel change.

Manual equivalent of the daily lane (CI owns it — rarely needed):

```sh
nix flake update
nix run nixpkgs#nix-update -- helium-browser --flake \
  --url https://github.com/imputnet/helium-linux \
  --override-filename modules/packages/helium.nix
```

## Secrets

sops-nix + age; every recipient is a host key, see [`.sops.yaml`](.sops.yaml):

- **Workstations** (`abraxas`, `sampo`, `hiisi`) are recipients on every file → any of them edits any secret. Maintain from whichever workstation you're on.
- **Servers** (`shodan`, `ukko`) decrypt only their own file (least privilege).

NixOS keys derive from the host's `/etc/ssh/ssh_host_ed25519_key`; the Mac uses a standalone age key at `~/.config/sops/age/keys.txt`. `homeManager.secrets` exports `SOPS_AGE_KEY_FILE` on every workstation, so editing just works:

```sh
sops secrets/env.yaml
```

From a box without the module, point sops at a workstation key:

```sh
export SOPS_AGE_KEY='AGE-SECRET-KEY-1…'   # a workstation key, e.g. from your password manager
sops secrets/env.yaml
```

After changing recipients in `.sops.yaml`, re-encrypt (from a host that already holds a current key for those files):

```sh
for f in secrets/*.yaml; do sops updatekeys --yes "$f"; done
```

## NixOS

```sh
HOST=hiisi
FLAKE="github:reuski/nix/main#$HOST"
HOSTDIR="$HOME/.local/state/reuski-nix/$HOST"
KEYDIR="$HOSTDIR/etc/ssh"
```

### Onboard (from a workstation)

Generate the host's SSH key, register its age recipient, re-encrypt the files it reads:

```sh
mkdir -p "$KEYDIR"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$KEYDIR/ssh_host_ed25519_key"
ssh-to-age -i "$KEYDIR/ssh_host_ed25519_key.pub"   # add as &$HOST in .sops.yaml

sops updatekeys --yes secrets/users.yaml
[ -f "secrets/$HOST.yaml" ] && sops updatekeys --yes "secrets/$HOST.yaml"
# laptops/desktops also read env.yaml:
# sops updatekeys --yes secrets/env.yaml
git add -A .sops.yaml secrets/ && git commit -m "onboard $HOST"
```

### Install — nixos-anywhere

Ships the pre-generated host key via `--extra-files`:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE" --extra-files "$HOSTDIR" root@<target-ip>
```

### Install — ISO

On the target:

```sh
sudo -i
# nmcli device wifi connect "SSID" password "PASSWORD"
systemctl start sshd && passwd && ip addr
```

From the workstation, push the key and install:

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

### Verify

```sh
systemctl status sops-install-secrets && ls /run/secrets
```

## nix-darwin

```sh
HOST=abraxas
FLAKE="github:reuski/nix/main#$HOST"
```

`abraxas` has no SSH host key — it decrypts with its standalone age key at `~/.config/sops/age/keys.txt`. Place that key first; generate it once if this is the Mac's first setup.

```sh
xcode-select --install
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

install -d -m 0700 "$HOME/.config/sops/age"
# first setup — generate the abraxas key (pubkey → .sops.yaml as &abraxas, then updatekeys);
# otherwise restore it from your password manager:
age-keygen -o "$HOME/.config/sops/age/keys.txt"
chmod 0600 "$HOME/.config/sops/age/keys.txt"

nix run github:nix-darwin/nix-darwin -- switch --flake "$FLAKE"
```

## Per-host post

### shodan

```sh
sudo tailscale up
sudo systemctl restart web-service-beebud web-service-wahuu-games caddy
```
