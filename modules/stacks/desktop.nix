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
        nixos.core
        nixos.boot
        nixos.metal
        nixos.networkmanager
        nixos.secrets
        nixos.users
        nixos.locale
        nixos.audio
        nixos.fonts
        nixos.plasma
        nixos.nix
        nixos.tailscale
        nixos.workstation
      ];

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
      homeManager.wallpaper
      homeManager.plasma
    ];
  };
}
