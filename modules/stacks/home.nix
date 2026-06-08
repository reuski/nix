{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager;
in
{
  flake.modules.homeManager.base =
    { config, ... }:
    {
      imports = [
        generic.profile
        homeManager.ghostty
        homeManager.zellij
        homeManager.fish
        homeManager.bat
        homeManager.direnv
        homeManager.delta
        homeManager.vim
        homeManager.eza
        homeManager.fzf
        homeManager.git
        homeManager.cli
        homeManager.pi
      ];

      home.username = config.profile.username;
      home.homeDirectory = config.profile.homeDirectory;
      home.stateVersion = config.home.version.release;

      programs.home-manager.enable = true;
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

  flake.modules.homeManager.mac = {
    imports = [ homeManager.base ];
  };
}
