{ config, ... }:
let
  inherit (config.flake.modules) generic nixos;
in
{
  flake.modules.nixos.server = {
    imports = [
      generic.profile
      nixos.nixpkgs
      nixos.common
      nixos.locale
      nixos.secrets
      nixos.headless
      nixos.vim
      nixos.nix
      nixos.podman
      nixos.proxy
      nixos.tailnet
      nixos.tailscale
    ];

    system.autoUpgrade = {
      allowReboot = true;
      dates = "04:00";
      rebootWindow = {
        lower = "04:00";
        upper = "06:00";
      };
    };
  };
}
