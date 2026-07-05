{ config, lib, ... }:
{
  home-manager.users.${config.profile.username} = {
    wallpaper.primary = "forage";
    programs.ghostty.settings.font-size = 14;
  };

  system.defaults.dock = {
    tilesize = lib.mkForce 64;
    autohide-delay = 0.0;
    autohide-time-modifier = 0.2;
  };
}
