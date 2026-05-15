# reuski/nix

Dendritic Nix flake for personal NixOS systems.

## Layout

- `flake.nix`: flake-parts entrypoint and recursive visible-module import.
- `modules/configurations/`: `configurations.{nixos,darwin}` registries, flake outputs, checks.
- `modules/hosts/`: concrete hosts plus private `_hardware.nix`, `_disko.nix`, and local helpers.
- `modules/stacks/`: reusable role compositions.
- `modules/nixos/`, `modules/home-manager/`, `modules/profile/`: reusable system and user modules.
- `modules/packages/`: overlayed custom packages.
- `modules/apps/update-custom.nix`: updater for custom package versions and hashes.

## Hosts

| Host | Role | Notes |
| --- | --- | --- |
| `hiisi` | Workstation | ThinkPad T480, disko-managed ext4 install, niri, Home Manager profile. |
| `shodan` | Server | UpCloud VPS, systemd-networkd, OpenSSH, Caddy, Bun-backed web apps. |

## Outputs

- `nixosConfigurations.{hiisi,shodan}`
- `packages.x86_64-linux.{helium-browser,python-validity,zjstatus}`
- `apps.x86_64-linux.update-custom`
- `formatter.x86_64-linux`

## Commands

```sh
nix fmt
nix flake check
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
sudo nixos-rebuild switch --flake .#<host>
nix run .#update-custom
```

## VPS Provisioning

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
