# AGENTS.md

## Contract

- Personal NixOS, nix-darwin, and Home Manager flake.
- Graph: `flake-parts` + `import-tree`.
- Public `modules/**/*.nix` files export flake-parts modules.
- Fresh installs only. No migrations, compatibility branches, or dead config.
- Verify with local or target-host Nix. CI is confirmation, not the primary check.

Hosts: `hiisi`, `sampo`, `shodan`, `ukko`, `abraxas`.

## Map

- `flake.nix`: inputs, `inputs.import-tree ./modules`.
- `modules/configurations/`: flake outputs and checks.
- `modules/stacks/`: composition only.
- `modules/{nixos,darwin,home-manager,generic}/`: reusable leaves.
- `modules/hosts/<host>/`: host entrypoints; `_*.nix` is private wiring.
- `modules/packages/`: overlays and custom packages.
- `secrets/*.yaml`: SOPS ciphertext only.

## Module Rules

- Read target modules before editing.
- Export reusable modules as `flake.modules.{nixos,darwin,homeManager,generic}.<name>`.
- Name files after exact ownership.
- Capture `inputs` in module top-level arguments.
- Do not use `specialArgs` or `extraSpecialArgs`.
- Use `lib.mkEnableOption` and typed `lib.mkOption`.
- Resolve executables with `lib.getExe` or `lib.getExe'`.
- Prefer upstream options before custom code.

## Service and Package Rules

- Prefer upstream options, then `quadlets.<name>`, then custom packages.
- Raw `virtualisation.quadlet` is for pods; exception: `modules/nixos/qbittorrent.nix`.
- Keep UI-owned service state out of Nix when API provisioning gets verbose.
- Packages must be terminal, browser, hardware, service, dev, or introspection.
- Do not add duplicate package surfaces.
- Do not add backup desktops.

## Inputs and Pins

- Keep `nixpkgs` rolling.
- Routine input/package refreshes are CI-owned.
- Local `flake.lock` edits are for input graph changes only.
- Isolate broken packages with fixed-rev `flake = false` pins.
- Scope pins to the host-private selector.
- Kernel pins import only the pinned kernel and use current nixpkgs' `linuxPackagesFor`.
- Do not pin NVIDIA, userspace, or package sets without failing-build proof.

## Secrets

- Use `sops-nix` + age.
- Recipients are host keys plus `admin`; use defaults unless needed.
- Use `sops.templates` for env files.
- Never edit secrets as plaintext.
- Never commit plaintext, decrypted exports, or private keys.

## Stack Boundaries

- No X11.
- No PulseAudio desktop stack.
- No legacy networking.

## Docs and Comments

- Docs are reference only.
- No tutorials, narrative prose, generated context dumps, or speculative rationale.
- Comments only for algorithmic rationale.

## Workflow

- Prefer `rg` and `rg --files`.
- Keep changes atomic.
- Delete superseded code and config.
- Do not add compatibility branches.
- Verify immediately after edits.
- If sandbox Nix is unavailable, use an accessible configured host or state the limitation.

## Validation

```sh
git diff --check
```

```sh
nix fmt .
nix flake check --no-build --all-systems
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
