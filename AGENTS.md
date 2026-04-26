# AGENTS.md

## Scope

Single-host NixOS flake for ThinkPad T480: `hiisi`, `x86_64-linux`.

Priorities: minimalism, unstable/current upstreams, performance, terminal-heavy daily use, web browsing, Linux exploration.

## Principles

- Prefer native NixOS/Home Manager options over scripts and ad-hoc files.
- Keep modules small and single-purpose; add files only to reduce complexity.
- Use current stack already chosen here: systemd-boot, latest kernel, initrd systemd, PipeWire, NetworkManager+iwd+resolved, nftables, niri, greetd, Ghostty, fish, Helix.
- Avoid fallbacks and legacy compatibility: no backup desktop, X11 path, PulseAudio, duplicate tools, or old-networking support.
- Add packages only for terminal work, browsing, hardware support, or system introspection.
- Remove obsolete config when upstream modules supersede it.

## Layout

- `flake.nix`: inputs, overlays, host wiring, custom updater.
- `hosts/hiisi/`: identity, disk layout, hardware facts.
- `modules/`: NixOS system policy.
- `home/reuski/`: Home Manager user/session config.
- `pkgs/`, `overlays/`: custom packages and exposure.

## Change Rules

- Do not run or casually alter disko/install paths; `hosts/hiisi/disko.nix` targets `/dev/nvme0n1` destructively.
- Do not bump `system.stateVersion` or `home.stateVersion` without explicit migration intent.
- Keep generated hardware facts in `hardware-configuration.nix`; put policy in `modules/`.
- Update custom package versions/hashes through `.#update-custom` when available.
- Use `lib.getExe`/`lib.getExe'` for executable paths.
- Match existing style; no mechanical comments.

## GitHub Actions

- `.github/workflows/nix.yml`: checks PRs/pushes by running the shared validate action.
- `.github/workflows/flake-lock.yml`: daily/manual flake and custom package update PRs with automerge.
- `.github/actions/validate`: CI-only syntax, formatting, and Nix evaluation checks.
