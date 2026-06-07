{ config, inputs, ... }:
let
  inherit (config.flake.modules) generic homeManager nixos;
in
{
  flake.modules.nixos.wayland =
    { config, ... }:
    {
      imports = [
        generic.profile
        nixos.nixpkgs
        nixos.cachix
        nixos.common
        nixos.boot
        nixos.networkmanager
        nixos.secrets
        nixos.users
        nixos.locale
        nixos.audio
        nixos.graphics
        nixos.power
        nixos.fonts
        nixos.niri
        nixos.nix
        nixos.tailscale
      ];

      nixpkgs.overlays = [
        inputs.niri.overlays.niri
      ];

      programs.localsend = {
        enable = true;
        openFirewall = true;
      };

      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.wayland ];
        profile = config.profile;
      };
    };
}
