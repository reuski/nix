{
  config,
  inputs,
  lib,
  ...
}:
let
  baseOverlays = [ config.flake.overlays.default ];
  waylandOverlays = [
    inputs.niri.overlays.niri
    inputs.ghostty.overlays.default
  ];
in
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = baseOverlays ++ lib.optionals (lib.hasSuffix "-linux" system) waylandOverlays;
        config.allowUnfree = true;
      };
    };

  flake.modules.nixos.nixpkgs = {
    nixpkgs.overlays = baseOverlays;
    nixpkgs.config.allowUnfree = true;
  };

  flake.modules.darwin.nixpkgs = {
    nixpkgs.overlays = baseOverlays;
    nixpkgs.config.allowUnfree = true;
  };
}
