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
        ];

        networking = {
          hostName = "shodan";
          domain = "reuski.dev";
        };

        systemd.network.networks."10-wan".networkConfig = {
          DHCP = lib.mkForce "ipv4";
          IPv6PrivacyExtensions = false;
        };

        nix.settings = {
          max-jobs = lib.mkForce 1;
          cores = lib.mkForce 1;
        };
        zramSwap.memoryPercent = lib.mkForce 100;
        services.journald.extraConfig = lib.mkForce ''
          SystemMaxUse=100M
          RuntimeMaxUse=50M
          MaxRetentionSec=2week
        '';

        site.autoUpgradeFlake = "github:reuski/nix/main";

        users.users.${config.profile.username}.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYOhwRvjVJHFoTPD02CCbvnvBUeS1eq1jSmUvfYCmbp sami@reuski.dev"
        ];

        services.tailscale = {
          enable = true;
          openFirewall = true;
        };

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
              envFile = "/var/lib/web/secrets/beebud.env";
            };

            wahuu-games = {
              domain = "wahuu.games";
              aliases = [ "www.wahuu.games" ];
              repo = "https://github.com/reuski/wahuu.games.git";
              port = 3000;
              envFile = "/var/lib/web/secrets/wahuu-games.env";
            };
          };
        };

        system.stateVersion = "25.11";
      };
  };
}
