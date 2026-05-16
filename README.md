# reuski/nix

Dendritic Nix flake for personal NixOS and nix-darwin systems.

## Layout

- `flake.nix`: flake-parts entrypoint, recursive visible-module import.
- `modules/configurations/`: `configurations.{nixos,darwin}` registries and flake outputs.
- `modules/hosts/`: concrete hosts with private `_hardware.nix`, `_disko.nix`, and local helpers.
- `modules/stacks/`: reusable stack compositions.
- `modules/nixos/`, `modules/darwin/`, `modules/home-manager/`, `modules/profile/`: reusable system and user modules.
- `modules/packages/`: overlayed custom packages.
- `modules/apps/update-custom.nix`: updater for custom package versions and hashes.

## Hosts

| Host      | Role    | Notes                                 |
| --------- | ------- | ------------------------------------- |
| `hiisi`   | Wayland | ThinkPad T480, disko ext4, niri       |
| `shodan`  | Server  | UpCloud VPS, systemd-networkd, Caddy  |
| `abraxas` | Mac     | MacBook, nix-darwin, Helium + Ghostty |

## Dev

```sh
nix fmt
nix flake check
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
nix run .#update-custom
sudo nixos-rebuild switch --flake .#<host>
darwin-rebuild switch --flake .#<host>
```

## Install

```sh
rfkill unblock all
nmcli device wifi connect "SSID" password "PASSWORD"
curl -fsSL https://github.com/reuski/nix/raw/main/install.sh | sh -s -- hiisi
```

## Post-Install

**abraxas**

```sh
darwin-rebuild switch --flake github:reuski/nix#abraxas
```

**shodan**

```sh
ssh reuski@shodan.reuski.dev
sudo tailscale up
sudo install -d -m 755 /var/lib/web
sudo install -d -m 700 /var/lib/web/keys /var/lib/web/secrets
sudoedit /var/lib/web/secrets/beebud.env
sudoedit /var/lib/web/secrets/wahuu-games.env
sudo systemctl restart web-service-beebud web-service-wahuu-games caddy
```

## Password Hash

```sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
systemd-firstboot --root="$tmp" --prompt-root-password --force --welcome=no
chmod u+r "$tmp/etc/shadow"
awk -F: '$1 == "root" { print $2 }' "$tmp/etc/shadow"
```
