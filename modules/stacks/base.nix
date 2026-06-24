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

      fonts.fontconfig.enable = false;

      programs.home-manager.enable = true;
    };
}
