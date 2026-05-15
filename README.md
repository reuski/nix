# nix

Dendritic Nix flake for NixOS systems.

## Structure

Visible `modules/**/*.nix` files are flake-parts modules. `_*.nix` files are local helpers. Reusable features are exported through `flake.modules.*` and composed into systems via `modules/hosts/` and `modules/stacks/`.

## Hosts

| Host   | Role        |
|--------|-------------|
| hiisi  | Workstation |
| shodan | Server      |

## Stacks

- **Workstation**: systemd-boot, NetworkManager+iwd+resolved, PipeWire, niri, greetd, Ghostty, fish, Helix.
- **Server**: systemd-networkd, OpenSSH, Caddy, Bun, git-backed web apps.

## Commands

```sh
# Format
nix fmt

# Update custom packages
nix run .#update-custom

# Check
nix flake check

# Evaluate a host
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath

# Rebuild
sudo nixos-rebuild switch --flake .#<host>
```
