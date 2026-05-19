{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.shodan = {
    channel = "stable";
    module =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        imports = [
          inputs.disko.nixosModules.disko
          ./_disko.nix
          ./_hardware.nix
          nixos.stackServer
          nixos.web
        ];

        networking = {
          hostName = "shodan";
          domain = "reuski.dev";
        };

        systemd.network.networks."10-wan".networkConfig = {
          DHCP = lib.mkForce "ipv4";
          IPv6PrivacyExtensions = false;
        };

        zramSwap.memoryPercent = lib.mkForce 100;
        services.journald.extraConfig = lib.mkForce ''
          SystemMaxUse=100M
          RuntimeMaxUse=50M
          MaxRetentionSec=2week
        '';

        web = {
          sites.reuski-dev = {
            domain = "reuski.dev";
            aliases = [ "www.reuski.dev" ];
            repo = "https://github.com/reuski/reuski.dev.git";
          };

          services = {
            beebud = {
              domain = "beebud.buzz";
              aliases = [ "www.beebud.buzz" ];
              repo = "https://github.com/reuski/beebud.git";
              port = 3001;
              start = "${lib.getExe pkgs.bun} build/index.js";
              envFile = config.sops.secrets."web/beebud/env".path;
            };

            wahuu-games = {
              domain = "wahuu.games";
              aliases = [ "www.wahuu.games" ];
              repo = "https://github.com/reuski/wahuu.games.git";
              port = 3000;
              envFile = config.sops.secrets."web/wahuu-games/env".path;
            };
          };
        };

        sops.secrets = {
          "web/beebud/env" = {
            owner = config.web.user;
            group = config.web.group;
            mode = "0400";
            restartUnits = [ "web-service-beebud.service" ];
          };
          "web/wahuu-games/env" = {
            owner = config.web.user;
            group = config.web.group;
            mode = "0400";
            restartUnits = [ "web-service-wahuu-games.service" ];
          };
        };

        system.stateVersion = "25.11";
      };
  };
}
