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
      nixos.secrets
      nixos.server
      nixos.vim
      nixos.nix
    ];

    site.autoUpgradeFlake = "github:reuski/nix/main";

    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
