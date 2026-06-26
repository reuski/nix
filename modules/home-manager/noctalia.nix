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
          panel = {
            borders = false;
            shadow = false;
          };
        };

        theme.builtin = "Gruvbox";

        wallpaper.enabled = false;

        location.auto_locate = true;

        bar.main = {
          thickness = 32;
          radius = 0;
          margin_ends = 0;
          margin_edge = 0;
          padding = 16;
          widget_spacing = 8;
          shadow = false;
          start = [ "workspaces" ];
          center = [ "clock" ];
          end = [
            "caffeine"
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
