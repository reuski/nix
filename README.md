# reuski/nix

Minimal Dendritic Nix flake.

Current target: ThinkPad T480 `hiisi` (`x86_64-linux`). Dormant nix-darwin plumbing exists for a future MacBook; VPS hosts should use separate minimal stacks.

## Design

Every visible `modules/**/*.nix` file is a top-level flake-parts module. Reusable features are exported through `flake.modules.*`; hosts and stacks compose them into concrete systems. `_*.nix` files are local helpers.

Foundation: unstable NixOS, systemd-boot, latest kernel, systemd initrd, PipeWire, NetworkManager+iwd+resolved, nftables, niri, greetd, Ghostty, fish, Helix.

No X11 fallback, backup desktop, PulseAudio, legacy networking, or duplicate tools.

## Layout

```text
flake.nix                 inputs and automatic module import
modules/configurations/   output builders
modules/hosts/            concrete hosts and local helpers
modules/stacks/           host-facing compositions
modules/nixos/            reusable NixOS modules
modules/home-manager/     reusable Home Manager modules
modules/profile/          shared identity/theme data
modules/packages/         overlays and custom packages
modules/apps/             flake apps
```

## Install

Destroys `/dev/nvme0n1`.

```sh
sudo -i
rfkill unblock all
nmcli device wifi connect "SSID" password "PASSWORD"
curl -L https://github.com/reuski/nix/raw/main/install.sh | sh
```

## Rebuild

```sh
sudo nixos-rebuild switch --flake github:reuski/nix/main#hiisi
```

Local checkout:

```sh
sudo nixos-rebuild switch --flake .#hiisi
```

## Validate / update

```sh
nix flake check
nix flake update
nix run .#update-custom
```

Eval only:

```sh
nix eval --raw .#nixosConfigurations.hiisi.config.system.build.toplevel.drvPath
```
