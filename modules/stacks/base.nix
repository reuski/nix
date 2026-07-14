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
        homeManager.delta
        homeManager.vim
        homeManager.eza
        homeManager.fzf
        homeManager.git
        homeManager.cli
      ];

      home.username = config.profile.username;
      home.homeDirectory = config.profile.homeDirectory;
      home.stateVersion = "26.11";

      fonts.fontconfig.enable = false;

      manual.manpages.enable = false;
      programs.man.generateCaches = false;
      programs.home-manager.enable = true;
    };
}
