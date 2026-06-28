# AGENTS.md

## Role

- Personal flake: NixOS, nix-darwin, Home Manager.
- Shape: dendritic, `flake-parts` + `import-tree`.
- Every non-private `modules/**/*.nix` file is a flake-parts module.
- Optimize for fresh installs. No migration shims.

## Graph

- `flake.nix`: inputs only; `inputs.import-tree ./modules`.
- `modules/configurations/`: `configurations.{nixos,darwin}` -> `nixosConfigurations`, `darwinConfigurations`, `checks`.
- `modules/stacks/`: imports only; no settings except class glue.
- `modules/nixos/`: NixOS leaves.
- `modules/darwin/`: nix-darwin leaves.
- `modules/home-manager/`: user-environment leaves.
- `modules/generic/`: cross-class leaves.
- `modules/hosts/<host>/`: real host entrypoints; `_*.nix` is host-private wiring.
- `modules/packages/`: overlays and custom packages.
- `secrets/*.yaml`: SOPS ciphertext only.

## Hosts

- `hiisi`: NixOS laptop, Niri.
- `sampo`: NixOS desktop, Plasma, gaming opt-in.
- `shodan`: NixOS VPS.
- `ukko`: NixOS home server.
- `abraxas`: nix-darwin Mac.

## Module Rules

- Export reusable modules as `flake.modules.{nixos,darwin,homeManager,generic}.<name>`.
- Name files after the option or role they own.
- Capture `inputs` in module top-level arguments.
- Do not use `specialArgs` or `extraSpecialArgs`.
- Use `lib.mkEnableOption` for toggles.
- Use typed `lib.mkOption` for public config.
- Resolve executables with `lib.getExe` or `lib.getExe'`.
- Prefer upstream NixOS/HM/darwin options.
- Then prefer `quadlets.<name>`.
- Use custom packages only when no upstream module/package shape fits.
- Raw `virtualisation.quadlet` is reserved for pods; current exception: `modules/nixos/qbittorrent.nix`.

## Stack Rules

- Stacks compose; leaves configure.
- `homeManager.base`: generic shell/editor/CLI only.
- `homeManager.dev`: dev toolchain, Zed, Pi agent/config.
- `nixos.core`: OS baseline for every NixOS host.
- `nixos.headless`: server baseline.
- `nixos.laptop`: laptop hardware/session stack.
- `nixos.desktop`: desktop hardware/session stack.
- `darwin.mac`: Darwin workstation baseline.
- Hosts import stacks plus host-private `_*.nix`.

## Service Plane

- `quadlets.<name>` feeds:
  - `virtualisation.quadlet.containers`
  - `proxy.services`
  - `media.directories`
- `proxy.services`: Caddy, ACME wildcard through Cloudflare DNS-01.
- `media.*`: shared media user/group/library dirs/container identity.
- `tailnet.services`: Tailscale Serve only.
- Heimdash cards derive from `proxy.services` in host config.
- Keep service API provisioning out of Nix when it becomes UI-owned state.

## Backups

- `nixos.backup`: `restic` over an `rclone` remote; provider swap = `backup.repository` + the rclone config.
- `backup.paths`: only unreproducible state a fresh install loses; never media or the Attic cache.
- Per-host secrets: `backup/restic-password` (keystone, encrypted in git), `backup/rclone-conf`.
- `backup.stampPath` feeds the heimdash `backup` card (age + freshness); failures POST to `backup.notify`.
- Restore on the host: `restic-<host> snapshots` / `restic-<host> restore latest --target /` (wrapper carries repo/password/rclone).

## Inputs

- Rolling unstable.
- Follow `nixpkgs` for every input except cache-backed GUI inputs.
- Cache-backed GUI inputs: `ghostty`, `noctalia`, `vicinae`.
- Trust matching caches in `modules/nixos/cachix.nix`.
- Do not hand-roll daily input bumps; CI owns them.

## Secrets

- Use `sops-nix` + age only.
- `.sops.yaml` recipients are host keys plus `admin`.
- Server host files include server key + `admin`.
- Workstation/bootstrap files include workstation keys + `admin`.
- NixOS host age keys derive from `/etc/ssh/ssh_host_ed25519_key.pub`.
- Darwin bootstrap key: `~/Library/Application Support/sops/age/keys.txt`.
- Cross-secret editing key: `secrets/admin.yaml` -> `admin_age_key`.
- `homeManager.secrets` exports `SOPS_AGE_KEY_FILE` to the decrypted admin key.
- Rely on SOPS defaults: root-owned, `0400`.
- Declare only differences: usually `restartUnits`, sometimes owner/group/mode.
- Use `sops.templates` for env files.
- Never commit plaintext, decrypted exports, or private keys outside encrypted SOPS values.

## Scope

- No X11.
- No PulseAudio desktop stack.
- No legacy networking.
- No duplicate package surfaces.
- No backup desktops.
- Add packages only for terminal, browser, hardware, service, dev, or introspection use.
- Keep docs reference-only. No narrative prose.
- Keep comments out of code unless algorithmic rationale is required.

## Validation

Local:

```sh
export SOPS_AGE_KEY="$(sops -d --extract '["admin_age_key"]' secrets/admin.yaml)"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
unset SOPS_AGE_KEY
git diff --check
```

CI:

```sh
nix fmt
nix flake check
```

## Agent Procedure

- Read the target modules before planning.
- Prefer `rg` and `rg --files`.
- Keep changes atomic.
- Delete superseded config.
- Do not add compatibility branches.
- Do not edit secrets as plaintext.
- Do not run local Nix when unavailable; state the limitation.
- Verify immediately after edits.
