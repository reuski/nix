{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.shodan = {
    channel = "stable";
    module =
      { lib, ... }:
      {
        imports = [
          inputs.disko.nixosModules.disko
          ./_disko.nix
          ./_hardware.nix
          nixos.server
          nixos.web
          ./_services.nix
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

        system.stateVersion = "25.11";
      };
  };
}
