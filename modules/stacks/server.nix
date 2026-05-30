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
      nixos.proxy
      nixos.tailnet
    ];

    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
