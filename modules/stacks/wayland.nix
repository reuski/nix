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
        nixos.cache
        nixos.common
        nixos.boot
        nixos.network
        nixos.secrets
        nixos.users
        nixos.locale
        nixos.audio
        nixos.graphics
        nixos.power
        nixos.fonts
        nixos.vim
        nixos.niri
        nixos.nix
      ];

      nixpkgs.overlays = [
        inputs.niri.overlays.niri
        inputs.ghostty.overlays.default
      ];

      services.tailscale = {
        enable = true;
        openFirewall = true;
      };

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
