# AGENTS.md

## Intent

Personal dendritic Nix flake for NixOS hosts, Home Manager profiles, and nix-darwin-ready configuration plumbing. Prefer upstream module options over custom services, generated files, or shell scripts.

## Shape

- `flake.nix` recursively imports visible Nix files under `modules/` through flake-parts.
- Visible `modules/**/*.nix` files are top-level flake-parts modules.
- `_*.nix` files are private host hardware, disko, or helper modules imported locally.
- Reusable features export through `flake.modules.{nixos,homeManager,generic}`.
- `modules/configurations/` turns `configurations.{nixos,darwin}` into flake outputs and checks.
- `modules/hosts/` contains real systems only: `hiisi` workstation and `shodan` server.
- `modules/stacks/` composes roles from reusable modules; hardware facts stay in host `_hardware.nix`.

## Rules

- Do not import feature modules directly from `flake.nix`.
- Do not add broad `specialArgs` or `extraSpecialArgs`; capture inputs in top-level modules.
- Keep modules small, typed, path-named, and single-purpose.
- Use upstream NixOS, Home Manager, and nix-darwin options before custom units or files.
- Remove superseded config instead of adding compatibility layers.
- Add only real hosts and real supported systems; no placeholders.
- Do not casually run or edit `install.sh`, disko, hardware, or disk device paths.
- Do not bump `system.stateVersion` or `home.stateVersion` without migration intent.
- Avoid X11, PulseAudio, legacy networking, duplicate tools, and backup desktops.
- Add packages only for terminal work, browsing, hardware, services, or introspection.
- Use `lib.getExe` or `lib.getExe'` for executable paths.
- Do not run local Nix commands by default; assume the editing platform may not be NixOS and may not have Nix installed.

## Validate

Formatting and config validation run in GitHub Actions. For local agent work, use repo-available checks only and report that Nix validation is delegated to CI.

```sh
git diff --check
bash -n install.sh
```
