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
        nixos.navidrome
        nixos.calibre
        nixos.tome
        nixos.maintainerr
        nixos.servarr
        nixos.qbittorrent
        nixos.hass
        nixos.vaultwarden
        nixos.valheim
        nixos.mumble
        nixos.skaldi
        nixos.cache
        nixos.deploy
      ];

      deploy = {
        cache = "ukko";
        stampPath = "/var/lib/heimdash/attic-primed";
        warm = [
          "sampo"
          "hiisi"
        ];
        targets = [ "shodan" ];
      };

      system.stateVersion = config.system.nixos.release;
    };
}
