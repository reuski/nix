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
        };

        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Gruvbox";
        };

        # Niri spawns swaybg at startup (modules/home-manager/niri.nix).
        wallpaper.enabled = false;

        bar.main = {
          position = "top";
          background_opacity = 0.92;
          margin_h = 0;
          margin_v = 0;
          radius = 0;
          shadow = false;
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
            command = "noctalia:dpms-off";
            resume_command = "noctalia:dpms-on";
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
