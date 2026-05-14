{
  config,
  inputs,
  ...
}:
let
  overlays = [
    config.flake.overlays.default
    inputs.niri.overlays.niri
    inputs.ghostty.overlays.default
  ];
in
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };
    };

  flake.modules.nixos.nixpkgs = {
    nixpkgs.overlays = overlays;
    nixpkgs.config.allowUnfree = true;
  };
}
