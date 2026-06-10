{ config, ... }:
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
        nixos.base
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
        nixos.localsend
        nixos.nix
        nixos.tailscale
      ];

      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.wayland ];
        profile = config.profile;
      };
    };

  flake.modules.homeManager.wayland = {
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
