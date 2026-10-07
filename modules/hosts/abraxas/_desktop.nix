{ config, lib, ... }:
{
  homebrew.casks = [ "signal" ];

  system.defaults.dock.persistent-apps = lib.mkAfter [
    "/Applications/Signal.app"
    "/Users/${config.profile.username}/Applications/Slack.app"
  ];

  home-manager.users.${config.profile.username} = {
    wallpaper.primary = "forage";
  };
}
