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
      nixos.homeServer
      nixos.stackServer
    ];

    networking.hostName = "ukko";

    system.stateVersion = "25.11";
  };
}
