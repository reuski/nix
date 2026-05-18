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
      nixos.boot
      nixos.stackServer
    ];

    networking.hostName = "ukko";

    site.autoUpgradeFlake = "github:reuski/nix/main";

    users.users.${config.profile.username}.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYOhwRvjVJHFoTPD02CCbvnvBUeS1eq1jSmUvfYCmbp sami@reuski.dev"
    ];

    system.stateVersion = "25.11";
  };
}
