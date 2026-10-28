{ config, ... }:
{
  profile.keyboard = {
    layout = "fi";
    variant = "nodeadkeys";
  };

  home-manager.users.${config.profile.username} = {
    wallpaper.primary = "plus";

    wayland.windowManager.niri.settings = {
      input = {
        touchpad = {
          tap = { };
          dwt = { };
          natural-scroll = { };
          click-method = "clickfinger";
        };
        trackpoint.accel-profile = "flat";
      };

      _children = [
        {
          output = {
            _args = [ "eDP-1" ];
            scale = 1.25;
          };
        }
        {
          window-rule._children = [
            { match._props.app-id = "ghostty"; }
            { open-maximized = true; }
          ];
        }
      ];
    };
  };
}
