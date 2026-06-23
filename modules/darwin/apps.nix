{ config, pkgs, ... }:
{
  flake.modules.darwin.apps = {
    homebrew.casks = [
      "firefox@developer-edition"
      "signal"
    ];
    home-manager.users.${config.profile.username}.home.packages = [ pkgs.localsend ];
  };
}
