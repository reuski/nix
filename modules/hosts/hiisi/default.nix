{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.hiisi.module = {
    imports = [
      inputs.disko.nixosModules.disko
      ./_disko.nix
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
      nixos.thinkpadT480
      ./_hardware.nix
      ./_fingerprint.nix
      nixos.stackWorkstation
    ];

    site.autoUpgradeFlake = "github:reuski/nix/main";
    system.stateVersion = "25.11";
  };
}
