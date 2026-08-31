# AGENTS.md

Project-specific rules for this NixOS, nix-darwin, and Home Manager flake.

## Architecture

- `flake.nix`: inputs and `inputs.import-tree ./modules`
- `modules/configurations/`: system outputs and checks
- `modules/stacks/`: composition only
- `modules/{nixos,darwin,home-manager,generic}/`: reusable leaves
- `modules/hosts/<host>/`: host entrypoints; `_*.nix` is private wiring
- `modules/packages/`: overlays and custom packages
- `secrets/*.yaml`: SOPS ciphertext only

Reusable leaves export `flake.modules.{nixos,darwin,homeManager,generic}.<name>`.
Root and configuration plumbing may configure flake-parts directly.

Hosts: `hiisi`, `sampo`, `shodan`, `ukko`, `abraxas`.

## Nix rules

- Fresh installs only. No migrations, compatibility branches, or dead config.
- Capture `inputs` in module top-level arguments.
- Do not use `specialArgs` or `extraSpecialArgs`.
- Use `lib.mkEnableOption` and typed `lib.mkOption`.
- Resolve executables with `lib.getExe` or `lib.getExe'`.
- Prefer upstream options, then `quadlets.<name>`, then custom packages.
- Raw `virtualisation.quadlet` is for pods; `modules/nixos/qbittorrent.nix`
  is the exception.
- Keep UI-owned service state out of Nix when API provisioning gets verbose.
- Custom packages are terminal, browser, hardware, service, dev, or
  introspection packages. Avoid duplicate package surfaces.
- Keep `nixpkgs` rolling. Change `flake.lock` locally only for input graph
  changes. Pin broken packages narrowly with fixed-revision `flake = false`
  inputs and build evidence.
- No X11, PulseAudio desktop stack, legacy networking, or backup desktops.
- Use `sops-nix` and age; use `sops.templates` for environment files.

## Checks

Private SSH access to `reuski/juttu` is required for evaluation.

```sh
nix fmt .
git diff --check
nix flake check --no-build --all-systems
python3 .github/scripts/check-sops-recipients.py
python3 .github/scripts/check-private-imports.py
```

```sh
nix build --no-link ".#checks.x86_64-linux.nixos-hiisi" --print-build-logs
nix build --no-link ".#checks.aarch64-darwin.darwin-abraxas" --print-build-logs
```
