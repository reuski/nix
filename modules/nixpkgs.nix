{
  config,
  inputs,
  ...
}:
let
  settings = {
    overlays = [ config.flake.overlays.default ];
    config.allowUnfree = true;
  };
in
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs (settings // { inherit system; });
    };

  flake.modules.nixos.nixpkgs.nixpkgs = settings;

  flake.modules.darwin.nixpkgs.nixpkgs = settings;
}
