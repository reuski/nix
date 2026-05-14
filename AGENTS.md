# AGENTS.md

## Scope

Single active host: ThinkPad T480 `hiisi`, `x86_64-linux`.

The repository follows the Dendritic pattern: every non-ignored Nix file under `modules/` is a top-level `flake-parts` module. Concrete NixOS, Home Manager, package, and future nix-darwin modules are exported through `flake.modules.*` and composed by host/stacks.

Future nix-darwin support may be added through `configurations.darwin`, but no macOS host is active until explicitly introduced.

## Priorities

Minimalism, unstable/current upstreams, performance, terminal-heavy daily use, web browsing, Linux exploration.

## Principles

- Prefer native NixOS/Home Manager/nix-darwin options over scripts and ad-hoc files.
- Keep modules small and single-purpose; a path should name the feature it exports.
- Use current stack already chosen here: systemd-boot, latest kernel, initrd systemd, PipeWire, NetworkManager+iwd+resolved, nftables, niri, greetd, Ghostty, fish, Helix.
- Avoid fallbacks and legacy compatibility: no backup desktop, X11 path, PulseAudio, duplicate tools, or old-networking support.
- Add packages only for terminal work, browsing, hardware support, or system introspection.
- Remove obsolete config when upstream modules supersede it.

## Layout

- `flake.nix`: inputs, flake-parts entrypoint, automatic `modules/` import.
- `modules/configurations/`: builders for `nixosConfigurations` and dormant `darwinConfigurations`.
- `modules/hosts/hiisi/`: only active host; `_hardware.nix` and `_disko.nix` are explicit host helpers ignored by auto-import.
- `modules/stacks/`: host-facing composition modules.
- `modules/nixos/`: reusable NixOS modules exported as `flake.modules.nixos.*`.
- `modules/home-manager/`: reusable Home Manager modules exported as `flake.modules.homeManager.*`.
- `modules/profile/`: shared profile module and assets.
- `modules/packages/`: overlays and package exposure.
- `modules/apps/`: flake apps such as `update-custom`.

## Dendritic Rules

- Do not import lower-level modules directly from `flake.nix`; compose through `configurations.*`, `flake.modules.*`, stacks, and hosts.
- Do not pass broad `specialArgs`/`extraSpecialArgs`; capture flake inputs in top-level modules and export lower-level modules that already contain what they need.
- Prefix non-top-level helper Nix files with `_` and import them explicitly from their owning top-level module.
- Keep `hiisi` as the only NixOS configuration until another real host is explicitly requested.

## Change Rules

- Do not run or casually alter disko/install paths; `modules/hosts/hiisi/_disko.nix` targets `/dev/nvme0n1` destructively.
- Do not bump `system.stateVersion` or `home.stateVersion` without explicit migration intent.
- Keep generated hardware facts in `modules/hosts/hiisi/_hardware.nix`; put policy in `modules/nixos/`.
- Update custom package versions/hashes through `.#update-custom` when available.
- Use `lib.getExe`/`lib.getExe'` for executable paths.
- Match existing style; no mechanical comments.

## GitHub Actions

- `.github/workflows/nix.yml`: checks PRs/pushes by running the shared validate action.
- `.github/workflows/flake-lock.yml`: daily/manual flake and custom package update PRs with automerge.
- `.github/actions/validate`: CI-only syntax, formatting, and Nix evaluation checks.
