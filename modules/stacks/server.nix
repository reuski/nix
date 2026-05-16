{ config, ... }:
let
  inherit (config.flake.modules) generic nixos;
in
{
  flake.modules.nixos.stackServer = {
    imports = [
      generic.profile
      nixos.nixpkgs
      nixos.locale
      nixos.server
      nixos.nix
      nixos.web
    ];
  };
}
