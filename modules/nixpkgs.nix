{
  config,
  inputs,
  ...
}:
let
  baseOverlays = [ config.flake.overlays.default ];
in
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = baseOverlays;
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
