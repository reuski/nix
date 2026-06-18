{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager nixos;
in
{
  flake.modules.nixos.laptop =
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
        nixos.power
        nixos.fonts
        nixos.niri
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
        imports = [ homeManager.laptop ];
        profile = config.profile;
      };
    };

  flake.modules.homeManager.laptop = {
    imports = [
      homeManager.base
      homeManager.packages
      homeManager.xdg
      homeManager.niri
      homeManager.noctalia
      homeManager.vicinae
      homeManager.gtk
    ];
  };
}
