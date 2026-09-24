# AGENTS.md

Repository-specific rules for this NixOS, nix-darwin, and Home Manager flake.
See `README.md` for layout, hosts, and commands.

## Placement

- User-owned packages and config go in `modules/home-manager/`; system-wide
  apps, services, networking, users, and GC go in `modules/nixos/` or `modules/darwin/`.
- `modules/stacks/` composes leaves only; host entrypoints live in `modules/hosts/<host>/`.
- `_*.nix` files are private wiring, excluded from `import-tree` and imported
  explicitly by their owner.
- `secrets/*.yaml` stays SOPS ciphertext; never commit plaintext or age keys.

## Nix

- Fresh installs only: no migrations, compatibility branches, or dead config.
- Capture `inputs` in module top-level arguments; no `specialArgs`/`extraSpecialArgs`.
- Use `lib.mkEnableOption` and typed `lib.mkOption`; resolve executables with
  `lib.getExe`/`lib.getExe'`.
- Prefer upstream options, then `quadlets.<name>`, then custom packages.
- Raw `virtualisation.quadlet` is for pods; `modules/nixos/qbittorrent.nix` is the exception.
- Keep UI-owned service state out of Nix when API provisioning gets verbose.
- Custom packages cover terminal, browser, hardware, service, dev, or introspection; avoid duplicate surfaces.
- Keep `nixpkgs` rolling; change `flake.lock` locally only for input-graph changes;
  pin broken packages narrowly with fixed-revision `flake = false` inputs and build evidence.
- No X11, PulseAudio, legacy networking, or backup desktops.
- Use `sops-nix` and age; `sops.templates` for environment files.

## Checks

Evaluation needs SSH access to the private `reuski/juttu` input. Before finishing,
run `nix fmt .`, `git diff --check`, and `nix flake check --no-build --all-systems`
(full list in `README.md`).
