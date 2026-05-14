# reuski/nix

Pure unstable NixOS flake for ThinkPad T480 `hiisi` (`x86_64-linux`).

Dendritic `flake-parts`: every visible `*.nix` under `modules/` is a top-level module. Features are exported through `flake.modules.*` and composed by stack/host modules.

## Stack

systemd-boot, latest kernel, systemd initrd, PipeWire, NetworkManager+iwd+resolved, nftables, niri, greetd, Ghostty, fish, Helix.

Wayland-only. No X11, fallback desktop, PulseAudio, legacy networking, or duplicate tooling.

## Tree

```text
flake.nix                 # inputs and module tree import
modules/configurations/   # output builders
modules/hosts/hiisi/      # active host; _disko.nix is destructive
modules/stacks/           # host composition
modules/nixos/            # NixOS modules
modules/home-manager/     # Home Manager modules
modules/profile/          # shared profile/assets
modules/packages/         # overlays/packages
modules/apps/             # flake apps
```

`configurations.darwin` exists only as dormant future plumbing.

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

## Update / validate

```sh
nix flake update
nix run .#update-custom
nix flake check
```

Eval only:

```sh
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
