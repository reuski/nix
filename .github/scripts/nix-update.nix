{ nixpkgs }:
let
  pkgs = (builtins.getFlake nixpkgs).legacyPackages.${builtins.currentSystem};
in
pkgs.nix-update.overrideAttrs (old: {
  # Nix 2.35 metadata can report a source path without copying it to the store.
  # Materialize each snapshot, including re-evaluations after package edits.
  # Remove when nix-update handles this upstream.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace nix_update/options.py \
      --replace-fail '"flake", "metadata", "--json"' '"flake", "archive", "--json"'
  '';
})
