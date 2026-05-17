{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager nixos;
in
{
  flake.modules.nixos.stackWayland =
    { config, ... }:
    {
      imports = [
        generic.profile
        nixos.nixpkgsWayland
        nixos.desktopCaches
        nixos.common
        nixos.boot
        nixos.networking
        nixos.users
        nixos.locale
        nixos.audio
        nixos.graphics
        nixos.power
        nixos.fonts
        nixos.niri
        nixos.nix
      ];

      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.wayland ];
        profile = config.profile;
      };
    };
}
