# AGENTS.md

## Intent

Minimal Dendritic Nix flake for personal systems. Prefer native NixOS, Home Manager, and nix-darwin options over scripts or generated files.

## Pattern

- Every visible `modules/**/*.nix` file is a top-level flake-parts module.
- `_*.nix` files are local helpers only.
- Export reusable features through `flake.modules.*`.
- Compose systems from `modules/hosts/` and `modules/stacks/`.
- Keep modules small, typed, path-named, and single-purpose.

## Rules

- Do not import feature modules directly from `flake.nix`.
- Do not add broad `specialArgs` / `extraSpecialArgs`; capture inputs in top-level modules.
- Use upstream module options before custom services, files, or shell scripts.
- Remove superseded config instead of layering fallbacks.
- Keep `hiisi` the only active NixOS host until a real host is added.
- Keep hardware facts in `modules/hosts/*/_hardware.nix`; policy belongs in reusable modules.
- Never casually run or edit install/disko paths; `modules/hosts/hiisi/_disko.nix` wipes `/dev/nvme0n1`.
- Do not bump `system.stateVersion` or `home.stateVersion` without migration intent.
- Avoid X11, PulseAudio, legacy networking, duplicate tools, and backup desktops.
- Add packages only when they serve terminal work, browsing, hardware, services, or introspection.
- Use `lib.getExe` / `lib.getExe'` for executable paths.
- Update custom package versions and hashes through `.#update-custom`.

## Validate

```sh
nix flake check
nix eval --raw .#nixosConfigurations.hiisi.config.system.build.toplevel.drvPath
```
