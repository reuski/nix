# AGENTS.md

## Contract

- Personal NixOS, nix-darwin, Home Manager flake.
- Graph: `flake-parts` + `import-tree`.
- Public `modules/**/*.nix` files export flake-parts modules.
- Fresh installs only. No migrations, compatibility branches, or dead config.
- Read target modules first.
- Verify with local or target-host Nix. CI is confirmation, not the primary check.

## Map

- `flake.nix`: inputs, `inputs.import-tree ./modules`.
- `modules/configurations/`: flake outputs and checks.
- `modules/stacks/`: imports only.
- `modules/{nixos,darwin,home-manager,generic}/`: reusable leaves.
- `modules/hosts/<host>/`: host entrypoints; `_*.nix` is private wiring.
- `modules/packages/`: overlays and custom packages.
- `secrets/*.yaml`: SOPS ciphertext only.

Hosts: `hiisi`, `sampo`, `shodan`, `ukko`, `abraxas`.

## Rules

- Export reusable modules as `flake.modules.{nixos,darwin,homeManager,generic}.<name>`.
- Name files after exact ownership.
- Capture `inputs` in module top-level arguments.
- Do not use `specialArgs` or `extraSpecialArgs`.
- Use `lib.mkEnableOption` and typed `lib.mkOption`.
- Resolve executables with `lib.getExe` or `lib.getExe'`.
- Prefer upstream options, then `quadlets.<name>`, then custom packages.
- Raw `virtualisation.quadlet` is for pods; exception: `modules/nixos/qbittorrent.nix`.
- Keep UI-owned service state out of Nix when API provisioning gets verbose.
- Keep `nixpkgs` rolling; isolate broken packages with fixed-rev `flake = false` pins.
- Scope pins to the host-private selector.
- Kernel pins import only the pinned kernel and use current nixpkgs' `linuxPackagesFor`.
- Secrets: `sops-nix` + age; host keys plus `admin`; defaults unless needed.
- Use `sops.templates` for env files.
- Never commit plaintext, decrypted exports, or private keys.
- No X11.
- No PulseAudio desktop stack.
- No legacy networking.
- No duplicate package surfaces.
- No backup desktops.
- Packages: terminal, browser, hardware, service, dev, or introspection only.
- Docs: reference only. No tutorials, narrative prose, or context dumps.
- Comments only for algorithmic rationale.

## Workflow

- Prefer `rg` and `rg --files`.
- Keep changes atomic.
- Delete superseded config.
- Do not add compatibility branches.
- Do not edit secrets as plaintext.
- Verify immediately after edits.
- If sandbox Nix is unavailable, use an accessible configured host or state the limitation.

## Validation

```sh
git diff --check
```

```sh
nix fmt .
nix flake check --no-build
nix eval .#checks.aarch64-darwin --apply 'builtins.mapAttrs (_: d: d.drvPath)'
```

```sh
HOST=hiisi
nix build --no-link ".#checks.x86_64-linux.nixos-$HOST" --print-build-logs
HOST=abraxas
nix build --no-link ".#checks.aarch64-darwin.darwin-$HOST" --print-build-logs
```

```sh
export SOPS_AGE_KEY="$(sops -d --extract '["admin_age_key"]' secrets/admin.yaml)"
for file in secrets/*.yaml; do sops -d "$file" >/dev/null; done
unset SOPS_AGE_KEY
```
