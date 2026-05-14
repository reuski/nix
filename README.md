# reuski/nix

Dendritic NixOS flake for one active machine: ThinkPad T480 `hiisi` (`x86_64-linux`).

The repo uses `flake-parts`; every non-ignored Nix file under `modules/` is a top-level module. Lower-level NixOS, Home Manager, package, and future nix-darwin modules are exported through `flake.modules.*` and composed by stacks/hosts.

## Layout

```text
flake.nix                    # flake-parts entrypoint and automatic modules/ import
modules/configurations/      # nixosConfigurations and dormant darwinConfigurations builders
modules/hosts/hiisi/         # only active host; _hardware.nix and _disko.nix are explicit helpers
modules/stacks/              # host-facing composition
modules/nixos/               # NixOS modules
modules/home-manager/        # Home Manager modules
modules/profile/             # shared profile and assets
modules/packages/            # overlays and package outputs
modules/apps/                # flake apps
```

`configurations.darwin` is present for future nix-darwin expansion, but no macOS host is defined.

## Install

```sh
sudo -i
rfkill unblock all
nmcli device wifi connect "SSID" password "PASSWORD"
curl -L https://github.com/reuski/nix/raw/main/install.sh | sh
```

`install.sh` runs disko against `/dev/nvme0n1`.

## Rebuild

```sh
sudo nixos-rebuild switch --flake github:reuski/nix/main#hiisi
```

Local checkout:

```sh
sudo nixos-rebuild switch --flake .#hiisi
```

## Update

```sh
nix flake update
nix run .#update-custom
nix eval --raw .#nixosConfigurations.hiisi.config.system.build.toplevel.drvPath
```

## Password hash

```sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
systemd-firstboot --root="$tmp" --prompt-root-password --force --welcome=no
chmod u+r "$tmp/etc/shadow"
awk -F: '$1 == "root" { print $2 }' "$tmp/etc/shadow"
```
