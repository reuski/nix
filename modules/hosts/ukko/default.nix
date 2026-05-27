{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.ukko.module = {
    imports = [
      inputs.disko.nixosModules.disko
      ./_disko.nix
      ./_hardware.nix
      ./_network.nix
      ./_services.nix
      nixos.boot
      nixos.server
      nixos.metal
      nixos.dashboard
      nixos.jellyfin
      nixos.servarr
      nixos.qbittorrent
      nixos.home-assistant
      nixos.janitorr
    ];

    system.stateVersion = "25.11";
  };
}
