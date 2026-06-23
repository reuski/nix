{ inputs, ... }:
{
  flake.modules.homeManager.noctalia = {
    imports = [ inputs.noctalia.homeModules.default ];

    programs.noctalia = {
      enable = true;

      settings = {
        shell = {
          font_family = "Hack Nerd Font Propo";
          corner_radius_scale = 0.5;
          polkit_agent = true;
          panel.shadow = false;
        };

        theme.builtin = "Gruvbox";

        wallpaper.enabled = false;

        bar.main = {
          margin_h = 0;
          margin_v = 0;
          radius = 0;
          shadow = false;
          background_opacity = 0.92;
          start = [ "workspaces" ];
          center = [ "clock" ];
          end = [
            "volume"
            "battery"
            "control-center"
          ];
        };

        idle = {
          pre_action_fade_seconds = 1.0;
          behavior."screen-off" = {
            enabled = true;
            timeout = 180;
          };
          behavior.suspend = {
            enabled = true;
            timeout = 900;
            command = "noctalia:session suspend";
          };
        };

        control_center.shortcuts = [
          { type = "wifi"; }
          { type = "bluetooth"; }
          { type = "nightlight"; }
          { type = "notification"; }
          { type = "power_profile"; }
          { type = "session"; }
        ];
      };
    };
  };
}
