{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.shodan.module =
    { config, lib, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        ./_hardware.nix
        nixos.server
        nixos.tiny
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

      system.stateVersion = config.system.nixos.release;
    };
}
