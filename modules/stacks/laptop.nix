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
        nixos.tailscale
        nixos.workstation
      ];

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
      homeManager.wallpaper
      homeManager.niri
      homeManager.noctalia
      homeManager.vicinae
      homeManager.gtk
    ];
  };
}
