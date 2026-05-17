{ config, ... }:
let
  inherit (config.flake.modules) generic nixos;
in
{
  flake.modules.nixos.stackServer = {
    imports = [
      generic.profile
      nixos.nixpkgs
      nixos.common
      nixos.locale
      nixos.server
      nixos.vim
      nixos.nix
      nixos.web
    ];

    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
