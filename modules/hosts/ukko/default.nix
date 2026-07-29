{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.ukko.module =
    { ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        ./_hardware.nix
        ./_network.nix
        ./_dns.nix
        ./_secrets.nix
        ./_services.nix
        ./_audio.nix
        ./_heimdash.nix
        ./_proxy.nix
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
        nixos.trek
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
        nixos.alerts
        nixos.backup
      ];

      deploy = {
        cache = "ukko";
        stampPath = "/var/lib/heimdash/attic-primed";
        notify = "http://127.0.0.1:2586/updates";
        warm = [
          "sampo"
          "hiisi"
        ];
        targets = [ "shodan" ];
      };

      alerts.ntfy = "http://127.0.0.1:2586/alerts";

      system.stateVersion = "26.11";
    };
}
