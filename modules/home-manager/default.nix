{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager;
in
{
  flake.modules.homeManager.reuski =
    { config, ... }:
    {
      imports = [
        generic.profile
        homeManager.packages
        homeManager.xdg
        homeManager.niri
        homeManager.noctalia
        homeManager.vicinae
        homeManager.ghostty
        homeManager.zellij
        homeManager.fish
        homeManager.bat
        homeManager.direnv
        homeManager.delta
        homeManager.helix
        homeManager.eza
        homeManager.fzf
        homeManager.git
        homeManager.cliTools
        homeManager.gtk
      ];

      home.username = config.profile.username;
      home.homeDirectory = config.profile.homeDirectory;
      home.stateVersion = "25.11";

      programs.home-manager.enable = true;
    };
}
