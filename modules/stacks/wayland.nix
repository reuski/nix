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
        nixos.vim
        nixos.niri
        nixos.nix
      ];

      nix.settings = {
        extra-substituters = [
          "https://niri.cachix.org"
          "https://noctalia.cachix.org"
          "https://vicinae.cachix.org"
        ];
        extra-trusted-public-keys = [
          "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
        ];
      };

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
