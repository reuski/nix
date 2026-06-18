{ config, ... }:
{
  home-manager.users.${config.profile.username} = {
    wallpaper.primary = "plus";

    programs.niri.settings = {
      input = {
        touchpad = {
          tap = true;
          natural-scroll = false;
          dwt = true;
          accel-profile = "adaptive";
          click-method = "clickfinger";
          scroll-method = "two-finger";
        };
        trackpoint = {
          accel-profile = "flat";
          accel-speed = 0.0;
        };
      };

      outputs."eDP-1" = {
        mode = {
          width = 1920;
          height = 1080;
          refresh = 60.000;
        };
        scale = 1.25;
        position = {
          x = 0;
          y = 0;
        };
      };
    };
  };
}
