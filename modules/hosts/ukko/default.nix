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
      nixos.heimdash
      nixos.media
      nixos.jellyfin
      nixos.audiobookshelf
      nixos.maintainerr
      nixos.servarr
      nixos.qbittorrent
      nixos.hass
      nixos.vaultwarden
      nixos.skaldi
    ];

    system.stateVersion = "25.11";
  };
}
