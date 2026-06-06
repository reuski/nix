# AGENTS.md

Personal Nix flake: NixOS, nix-darwin, Home Manager.

## Shape

- `flake.nix` → `import-tree` loads all of `modules/` into flake-parts; `_`-prefixed paths are skipped.
- Reusable code exports as `flake.modules.{nixos,darwin,homeManager,generic}.<name>` — one module per file, named for the option it owns.
- `modules/configurations/` lifts those into `configurations.{nixos,darwin}` → flake outputs + per-system `checks`.
- `modules/hosts/<host>/` — real systems only (`hiisi` laptop, `shodan` VPS, `ukko` home server, `abraxas` Mac); `_*.nix` are that host's private hardware/disko/service helpers, imported by its `default.nix`.
- `modules/stacks/` composes modules into roles (`server`, `wayland`, …); `modules/packages/` = overlays + custom pkgs; `modules/apps/` = the `update-custom` app.
- `secrets/*.yaml` = SOPS ciphertext.

## Rules

- **Modules:** every feature is a `flake.modules` module; never import from `flake.nix`. No `specialArgs`/`extraSpecialArgs` — capture `inputs` in the top-level function. Keep them small, typed, single-purpose, name = option namespace; mirror an existing `modules/nixos/*.nix`.
- **Implementation ladder:** upstream NixOS/HM/darwin option → upstream container via `quadlets.<name>` (`modules/nixos/quadlets.nix`) → custom package. Raw `virtualisation.quadlet` only for pods (`modules/nixos/qbittorrent.nix`). Resolve binaries with `lib.getExe`/`getExe'`.
- **Clean-slate:** no backwards compatibility — every change targets the ideal fresh install, never a migration. Delete superseded config; no shims, fallbacks, dead conditionals, or `backupFileExtension`. Optimize disko, hardware, device paths, and `*.stateVersion` freely (stateVersion tracks the channel). Rolling unstable — every input `follows` `nixpkgs`, no version pins.
- **Hosts:** real hosts + supported systems only (`modules/systems.nix`). Servers auto-upgrade + reboot 04:00–06:00 on kernel change; desktops stage for manual reboot.
- **Scope:** no X11, PulseAudio, legacy networking, duplicate tools, or backup desktops. Add packages only for terminal, browsing, hardware, services, or introspection.
- **Darwin:** Determinate Nix owns the daemon (`nix.enable = false`); `nix-homebrew` installs Homebrew, packages go through `homebrew.*`.
- **Secrets:** sops-nix + age only. Recipients from `/etc/ssh/ssh_host_ed25519_key.pub` via `ssh-to-age`; admin key `~/.config/sops/age/keys.txt`; `sops updatekeys` after `.sops.yaml` changes. Never commit private keys, decrypted exports, or plaintext.
- **Local:** don't run Nix here (platform may lack it); CI (`.github/workflows/nix.yml`) builds every host.

## Validate

Local:

```sh
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
git diff --check
```
