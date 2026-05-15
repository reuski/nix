# reuski/nix

Dendritic Nix flake for personal NixOS and nix-darwin systems.

## Layout

- `flake.nix`: flake-parts entrypoint and recursive visible-module import.
- `modules/configurations/`: `configurations.{nixos,darwin}` registries, flake outputs, checks.
- `modules/hosts/`: concrete hosts plus private `_hardware.nix`, `_disko.nix`, and local helpers.
- `modules/stacks/`: reusable role compositions.
- `modules/nixos/`, `modules/darwin/`, `modules/home-manager/`, `modules/profile/`: reusable system and user modules.
- `modules/packages/`: overlayed custom packages.
- `modules/apps/update-custom.nix`: updater for custom package versions and hashes.

## Hosts

| Host | Role | Notes |
| --- | --- | --- |
| `hiisi` | Workstation | ThinkPad T480, disko-managed ext4 install, niri, Home Manager profile. |
| `shodan` | Server | UpCloud VPS, systemd-networkd, OpenSSH, Caddy, Bun-backed web apps. |
| `abraxas` | Macbook | Apple Silicon, nix-darwin, Helium + Ghostty via Homebrew, fish + zellij. |

## Outputs

- `nixosConfigurations.{hiisi,shodan}`
- `darwinConfigurations.abraxas`
- `packages.x86_64-linux.{helium-browser,python-validity,zjstatus}`
- `packages.aarch64-darwin.zjstatus`
- `apps.x86_64-linux.update-custom`
- `formatter.{x86_64-linux,aarch64-darwin}`

## Commands

```sh
nix fmt
nix flake check
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
sudo nixos-rebuild switch --flake .#<host>
darwin-rebuild switch --flake .#<host>
nix run .#update-custom
```

## Macbook

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
nix run nix-darwin/master -- switch --flake github:reuski/nix/main#abraxas
darwin-rebuild switch --flake .#abraxas
```

## VPS

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake github:reuski/nix/main#shodan \
  --target-host root@<ip>
```

```sh
ssh reuski@<ip>
sudo tailscale up
sudo install -d -m 700 /var/lib/webapps/secrets
sudoedit /var/lib/webapps/secrets/wahuu-games.env
```

## Password Hash

```sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
systemd-firstboot --root="$tmp" --prompt-root-password --force --welcome=no
chmod u+r "$tmp/etc/shadow"
awk -F: '$1 == "root" { print $2 }' "$tmp/etc/shadow"
```
