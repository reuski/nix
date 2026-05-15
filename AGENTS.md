# AGENTS.md

## Intent

Dendritic Nix flake. Prefer native NixOS, Home Manager, and nix-darwin module options over custom scripts or generated files.

## Pattern

- Visible `modules/**/*.nix` files are top-level flake-parts modules.
- `_*.nix` files are local helpers imported by visible modules.
- Export reusable features through `flake.modules.*`.
- Compose systems from `modules/hosts/` and `modules/stacks/`.
- Keep modules small, typed, path-named, and single-purpose.

## Rules

- Do not import feature modules directly from `flake.nix`.
- Do not add broad `specialArgs` / `extraSpecialArgs`; capture inputs in top-level modules.
- Use upstream module options before custom services, files, or shell scripts.
- Remove superseded config instead of layering fallbacks.
- Add only real hosts; no placeholders.
- Keep hardware facts in `modules/hosts/*/_hardware.nix`; policy belongs in reusable modules.
- Never casually run or edit install/disko paths.
- Do not bump `system.stateVersion` or `home.stateVersion` without migration intent.
- Avoid X11, PulseAudio, legacy networking, duplicate tools, and backup desktops.
- Add packages only for terminal work, browsing, hardware, services, or introspection.
- Use `lib.getExe` / `lib.getExe'` for executable paths.

## Validate

```sh
nix flake check
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
```
