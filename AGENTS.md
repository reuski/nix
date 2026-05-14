# AGENTS.md

## Scope

One active target: ThinkPad T480 `hiisi`, `x86_64-linux`.

This is a Dendritic `flake-parts` NixOS flake. Every visible `*.nix` file under `modules/` is a top-level flake-parts module. Concrete NixOS, Home Manager, package, app, and dormant nix-darwin outputs are exported through `flake.modules.*` / `configurations.*` and composed by stacks/hosts.

## Direction

- Minimal, current, terminal-first, Wayland-only.
- Prefer upstream unstable/master inputs when intentionally chosen.
- Use native NixOS/Home Manager/nix-darwin options before scripts or files.
- Keep modules tiny, typed, single-purpose, and path-named.
- Remove superseded config instead of layering fallbacks.
- Add packages only for terminal work, browsing, hardware, or introspection.

## Stack

systemd-boot, latest kernel, systemd initrd, PipeWire, NetworkManager+iwd+resolved, nftables, niri, greetd, Ghostty, fish, Helix.

No backup desktop, X11 path, PulseAudio, legacy networking, duplicate tools, mutable-user drift, or compatibility scaffolding.

## Layout

- `flake.nix`: inputs and automatic `modules/` import.
- `modules/configurations/`: NixOS and dormant Darwin builders.
- `modules/hosts/hiisi/`: only active host; `_hardware.nix` and `_disko.nix` are explicit helpers.
- `modules/stacks/`: host-facing composition.
- `modules/nixos/`: reusable NixOS modules.
- `modules/home-manager/`: reusable Home Manager modules.
- `modules/profile/`: shared identity, locale, colors, assets.
- `modules/packages/`: overlays and packages.
- `modules/apps/`: flake apps.

## Rules

- Do not import feature modules directly from `flake.nix`.
- Do not pass broad `specialArgs` / `extraSpecialArgs`; capture inputs in top-level modules.
- Prefix non-top-level helper Nix files with `_`.
- Keep `hiisi` the only NixOS configuration until a real host is requested.
- Never casually run or alter disko/install paths; `_disko.nix` destroys `/dev/nvme0n1`.
- Do not bump `system.stateVersion` or `home.stateVersion` without migration intent.
- Keep generated hardware facts in `_hardware.nix`; policy belongs in `modules/nixos/`.
- Update custom package versions/hashes through `.#update-custom`.
- Use `lib.getExe` / `lib.getExe'` for executable paths.
- Match existing formatting; no mechanical comments.

## CI

- `.github/actions/validate`: syntax, format, eval, package smoke builds.
- `.github/workflows/nix.yml`: PR/push validation and autofix PRs.
- `.github/workflows/flake-lock.yml`: scheduled lock/custom-package update PRs.
