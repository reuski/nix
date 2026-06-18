{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager nixos;
in
{
  flake.modules.nixos.desktop =
    { config, ... }:
    {
      imports = [
        generic.profile
        nixos.nixpkgs
        nixos.cachix
        nixos.core
        nixos.boot
        nixos.networkmanager
        nixos.secrets
        nixos.users
        nixos.locale
        nixos.audio
        nixos.fonts
        nixos.plasma
        nixos.nix
      ];

      hardware.graphics.enable = true;

      programs.localsend = {
        enable = true;
        openFirewall = true;
      };

      services.tailscale = {
        enable = true;
        openFirewall = true;
      };

      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.desktop ];
        profile = config.profile;
      };
    };

  flake.modules.homeManager.desktop = {
    imports = [
      homeManager.base
      homeManager.packages
      homeManager.xdg
      homeManager.gtk
    ];
  };
}
