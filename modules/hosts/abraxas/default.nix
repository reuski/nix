{ config, ... }:
let
  inherit (config.flake.modules) darwin;
in
{
  configurations.darwin.abraxas.module = {
    imports = [ darwin.stackMac ];

    networking.hostName = "abraxas";
    networking.computerName = "abraxas";
    networking.localHostName = "abraxas";

    nixpkgs.hostPlatform = "aarch64-darwin";

    system.stateVersion = 6;
  };
}
