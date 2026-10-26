{ config, ... }:
{
  profile.keyboard = {
    layout = "fi";
    variant = "nodeadkeys";
  };

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

      outputs."eDP-1".scale = 1.25;

      window-rules = [
        {
          matches = [ { app-id = "ghostty"; } ];
          open-maximized = true;
        }
      ];
    };
  };
}
