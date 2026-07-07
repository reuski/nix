{ config, lib, ... }:
{
  system.defaults.dock.persistent-apps = lib.mkAfter [
    "/Users/${config.profile.username}/Applications/Slack.app"
  ];

  home-manager.users.${config.profile.username} = {
    wallpaper.primary = "forage";
  };
}
