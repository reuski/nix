{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.shodan.module =
    { lib, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        ./_hardware.nix
        ./_ssh.nix
        nixos.server
        nixos.web
        nixos.tailnet
        ./_services.nix
      ];

      networking.domain = "reuski.dev";

      system.autoUpgrade.enable = lib.mkForce false;

      nix.gc = {
        dates = "01:00";
        options = "--delete-older-than 3d";
      };
      nix.settings = {
        min-free = 1 * 1024 * 1024 * 1024;
        max-free = 2 * 1024 * 1024 * 1024;
      };

      services.tailscale = {
        useRoutingFeatures = "client";
        extraSetFlags = [
          "--ssh"
          "--accept-routes=true"
        ];
      };

      systemd.network.networks."10-wan".networkConfig = {
        DHCP = lib.mkForce "ipv4";
        IPv6PrivacyExtensions = false;
      };

      system.stateVersion = "26.11";
    };
}
