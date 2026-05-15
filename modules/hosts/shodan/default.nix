{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.shodan.module =
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

      systemd.network = {
        config.networkConfig.IPv6PrivacyExtensions = false;
        networks."10-wan".networkConfig.DHCP = lib.mkForce "ipv4";
      };

      site.autoUpgradeFlake = "github:reuski/nix/main";

      users.users.${config.profile.username}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYOhwRvjVJHFoTPD02CCbvnvBUeS1eq1jSmUvfYCmbp sami@reuski.dev"
      ];

      services.tailscale = {
        enable = true;
        openFirewall = true;
      };

      webApps = {
        repos = {
          reuski-dev.url = "https://github.com/reuski/reuski.dev.git";
          wahuu-games.url = "https://github.com/reuski/wahuu.games.git";
        };

        sites.reuski-dev = {
          domains = [ "reuski.dev" ];
          repo = "reuski-dev";
        };

        services.wahuu-games = {
          domains = [ "wahuu.games" ];
          repo = "wahuu-games";
          port = 3000;
          build = "${lib.getExe pkgs.bun} run build";
          envFiles = [ "/var/lib/webapps/secrets/wahuu-games.env" ];
        };
      };

      system.stateVersion = "25.11";
    };
}
