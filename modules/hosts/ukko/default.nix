{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.ukko.module =
    { config, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        ./_hardware.nix
        ./_network.nix
        ./_services.nix
        nixos.boot
        nixos.server
        nixos.metal
        nixos.proxy
        nixos.tailnet
        nixos.quadlets
        nixos.heimdash
        nixos.media
        nixos.jellyfin
        nixos.audiobookshelf
        nixos.calibre
        nixos.maintainerr
        nixos.servarr
        nixos.qbittorrent
        nixos.hass
        nixos.vaultwarden
        nixos.skaldi
      ];

      system.stateVersion = config.system.nixos.release;
    };
}
