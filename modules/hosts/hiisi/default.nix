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
      ./_hardware.nix
      nixos.stackHiisi
    ];

    networking.hostName = "hiisi";
    system.stateVersion = "25.11";
  };
}
