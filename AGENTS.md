# AGENTS.md

Personal Nix flake: NixOS, nix-darwin, Home Manager. Dendritic — flake-parts + import-tree, every file is a flake-parts module.

## Shape

- `flake.nix` → `import-tree` loads all of `modules/` into flake-parts; `_`-prefixed paths are skipped.
- Reusable code exports as `flake.modules.{nixos,darwin,homeManager,generic}.<name>` — one module per file, named for the option it owns (`jellyfin.nix` → `options.jellyfin`).
- `modules/configurations/` lifts `configurations.{nixos,darwin}` into flake outputs + per-system `checks` — CI builds exactly these.
- `modules/hosts/<host>/` — real systems only: `hiisi` (Niri laptop), `sampo` (Plasma gaming desktop), `shodan` (VPS), `ukko` (home server), `abraxas` (Mac). `_*.nix` are that host's private hardware/disko/network/service wiring, imported by its `default.nix`.
- `modules/stacks/` — roles, one per file, pure composition (imports only); a role may export the same name across classes:
  - `server.nix` → `nixos.server`: headless server; its settings live in the `nixos.headless` leaf (LTS kernel, trimmed closure, auto-upgrade + reboot).
  - `laptop.nix` → `nixos.laptop` + `homeManager.laptop`: Niri laptop; compositor via `nixos.niri`/`homeManager.niri`, plus `nixos.power` (upower, PPD, networkmanager wifi).
  - `desktop.nix` → `nixos.desktop` + `homeManager.desktop`: Plasma 6 desktop; compositor via `nixos.plasma` leaf; gaming is host-opt-in via `nixos.gaming` (Steam, gamemode, gamescope, 32-bit). No power/wifi laptop-isms.
  - `mac.nix` → `darwin.mac`: Darwin workstation; system config via nix-darwin, GUI apps via Homebrew, user env via the same `homeManager.base`.
  - `base.nix` → `homeManager.base`: CLI/home every user env gets; `nixos.core` (`modules/nixos/core.nix`) is the OS-level leaf every NixOS host imports.
- `modules/generic/` — cross-class modules: `profile` (identity: user, locale, keyboard, colors) and `editor` (shared vimrc consumed by both `nixos.vim` and `homeManager.vim`).
- Server service plane (ukko): `quadlets.<name>` payloads feed `proxy.services` (Caddy, ACME wildcard via Cloudflare DNS-01), `media.*` (shared identity + tmpfiles directories), and `tailnet.services` (Tailscale Serve); heimdash cards are built from `proxy.services`.
- `modules/packages/` — overlays + custom pkgs, exported through `perSystem.packages`; inputs without `nixpkgs` follows (ghostty, noctalia, vicinae) are consumed via overlay from their flake outputs for binary-cache hits, with `modules/nixos/cachix.nix` trusting their caches.
- `secrets/*.yaml` = SOPS ciphertext.

## Rules

- **Modules:** every feature is a `flake.modules` module; never import from `flake.nix`. No `specialArgs`/`extraSpecialArgs` — capture `inputs` in the top-level function. Keep them small, typed, single-purpose; each module owns the top-level option named after its file; `media.*` is only the shared identity/directories module. Toggles use `lib.mkEnableOption`; mirror an existing `modules/nixos/*.nix`.
- **Stacks compose, leaves configure:** `modules/stacks/*` files only import and wire modules; settings live in class leaf modules (`modules/{nixos,darwin,home-manager,generic}/`). Hosts import stacks plus host-specific service modules and keep `_*.nix` for non-reusable wiring.
- **Implementation ladder:** upstream NixOS/HM/darwin option → upstream container via `quadlets.<name>` (`modules/nixos/quadlets.nix`) → custom package. Raw `virtualisation.quadlet` only for pods (`modules/nixos/qbittorrent.nix` is the sole case). Resolve binaries with `lib.getExe`/`getExe'`.
- **Clean-slate:** no backwards compatibility — every change targets the ideal fresh install, never a migration. Delete superseded config; no shims, fallbacks, dead conditionals, or `backupFileExtension`. Optimize disko, hardware, device paths, and `*.stateVersion` freely (stateVersion tracks the channel). Rolling unstable — every input `follows` `nixpkgs` except cache-backed GUI inputs above; no version pins.
- **Hosts:** real hosts + supported systems only (`modules/systems.nix`). Servers auto-upgrade + reboot 04:00–06:00 on kernel change; desktops stage for manual reboot.
- **Scope:** no X11, PulseAudio, legacy networking, duplicate tools, or backup desktops. Add packages only for terminal, browsing, hardware, services, or introspection.
- **Darwin:** Determinate Nix owns the daemon (`nix.enable = false`); `nix-homebrew` installs Homebrew, packages go through `homebrew.*`; secrets via sops-nix's Home Manager module (no host SSH key — dedicated age key).
- **Secrets:** sops-nix + age only. NixOS recipients from `/etc/ssh/ssh_host_ed25519_key.pub` via `ssh-to-age`; darwin decrypts in Home Manager. Admin key `~/.config/sops/age/keys.txt` on every platform — `homeManager.secrets` ships the tooling, `SOPS_AGE_KEY_FILE`, and the HM `sops.age.keyFile`; `sops updatekeys` after `.sops.yaml` changes. Rely on sops defaults (root-owned, `0400`) — declare only what differs, usually just `restartUnits`. Compose env files with `sops.templates`. Never commit private keys, decrypted exports, or plaintext.
- **Local:** don't run Nix here (platform may lack it); CI (`.github/workflows/nix.yml`) formats, builds every NixOS host, and evaluates the darwin host. `.github/workflows/flake-lock.yml` does the daily input/package bumps — don't hand-roll updates that lane already covers.

## Validate

Local:

```sh
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
git diff --check
```

CI gates the rest: `nix fmt` + `nix flake check` (builds all host toplevels) on every PR/push.
