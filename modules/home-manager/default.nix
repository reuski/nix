{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager;
in
{
  flake.modules.homeManager.base =
    { config, pkgs, ... }:
    {
      imports = [
        generic.profile
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
      ];

      home.username = config.profile.username;
      home.homeDirectory = config.profile.homeDirectory;
      home.stateVersion = "25.11";
      home.packages = [ pkgs.zellij ];

      programs.home-manager.enable = true;
    };

  flake.modules.homeManager.reuski = {
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

  flake.modules.homeManager.reuskiMac = {
    imports = [ homeManager.base ];
  };
}
