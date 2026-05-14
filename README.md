# reuski/nix

Minimal Dendritic Nix flake for personal systems.

## Shape

Visible `modules/**/*.nix` files are flake-parts modules. `_*.nix` files are local helpers. Hosts compose reusable modules through `modules/stacks/`.

## Hosts

- `hiisi`: laptop.
- `shodan`: server at `shodan.reuski.dev`.

## Stack

- Base: NixOS unstable, latest Linux, nftables.
- Workstation: systemd-boot, NetworkManager+iwd+resolved, PipeWire, niri, greetd, Ghostty, fish, Helix.
- Server: systemd-networkd, OpenSSH key auth, Caddy, Bun, Git-backed web apps.

## Web

- `reuski.dev`: static site from `github:reuski/reuski.dev`.
- `wahuu.games`: Bun service from `github:reuski/wahuu.games`.

Repos sync to `/var/lib/webapps/repos`; app state lives in `/var/lib/webapps/apps`. Private deploy keys live in `/var/lib/webapps/keys`; secrets live in `/var/lib/webapps/secrets`.

```sh
sudo systemctl restart web-site-reuski-dev.service
sudo systemctl restart web-service-wahuu-games.service
```

## Install hiisi

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
sudo nixos-rebuild switch --flake github:reuski/nix/main#shodan
```

## Validate

```sh
nix flake check
nix eval --raw .#nixosConfigurations.hiisi.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.shodan.config.system.build.toplevel.drvPath
```
