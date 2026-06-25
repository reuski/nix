{ config, ... }:
let
  inherit (config.flake.modules) generic nixos;
in
{
  flake.modules.nixos.server = {
    imports = [
      generic.profile
      nixos.nixpkgs
      nixos.cachix
      nixos.core
      nixos.headless
      nixos.networkd
      nixos.ssh
      nixos.hardening
      nixos.locale
      nixos.secrets
      nixos.vim
      nixos.nix
    ];

    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
