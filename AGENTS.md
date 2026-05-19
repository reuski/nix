# AGENTS.md

Personal Nix flake: NixOS, nix-darwin, Home Manager.

## Shape

- `flake.nix` recursively imports visible `modules/**/*.nix` via flake-parts.
- `_*.nix` files are private host helpers (hardware, disko).
- Reusable modules export through `flake.modules.{nixos,darwin,homeManager,generic}`.
- `modules/configurations/` registers `configurations.{nixos,darwin}` outputs.
- `modules/hosts/` holds real systems only: `hiisi`, `shodan`, `ukko`, `abraxas`.
- `modules/stacks/` composes reusable stacks; per-host hardware lives in `_hardware.nix`.
- `secrets/*.yaml` is SOPS ciphertext.

## Rules

- Route every feature through `flake.modules`; never import directly from `flake.nix`.
- No `specialArgs` / `extraSpecialArgs`. Capture inputs in top-level modules.
- Modules are small, typed, path-named, single-purpose.
- Prefer upstream NixOS, Home Manager, and nix-darwin options over custom files or scripts.
- Delete superseded config; no compatibility shims.
- Real hosts and supported systems only.
- Never casually edit disko, hardware, or device paths.
- Do not bump `system.stateVersion` or `home.stateVersion` without migration intent.
- No X11, PulseAudio, legacy networking, duplicate tools, or backup desktops.
- Add packages only for terminal, browsing, hardware, services, or introspection.
- Resolve binaries with `lib.getExe` / `lib.getExe'`.
- Darwin hosts assume Determinate Nix manages the daemon; keep `nix.enable = false`.
- Darwin Homebrew installation is managed by `nix-homebrew`; packages use nix-darwin `homebrew.*`.
- Do not run Nix locally; the editing platform may lack Nix.
- Secrets: sops-nix + age only.
- NixOS recipients: `/etc/ssh/ssh_host_ed25519_key.pub` via `ssh-to-age`.
- Admin age key: `~/.config/sops/age/keys.txt`.
- No private age keys, decrypted exports, or plaintext secrets in git.
- After `.sops.yaml` recipient changes, run `sops updatekeys`.

## Validate

Local:

```sh
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
git diff --check
```
