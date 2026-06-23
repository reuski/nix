{ config, ... }:
{
  home-manager.users.${config.profile.username} = {
    wallpaper.primary = "plus";

    programs.niri.settings = {
      input = {
        touchpad = {
          tap = true;
          dwt = true;
          click-method = "clickfinger";
        };
        trackpoint.accel-profile = "flat";
      };

      outputs."eDP-1" = {
        mode = {
          width = 1920;
          height = 1080;
          refresh = 60.000;
        };
        scale = 1.25;
      };
    };
  };
}
