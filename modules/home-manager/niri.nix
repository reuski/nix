{ ... }:
{
  flake.modules.homeManager.niri =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      brightnessctl = lib.getExe pkgs.brightnessctl;
      ghostty = lib.getExe pkgs.ghostty;
      helium = lib.getExe pkgs.helium-browser;
      noctalia = lib.getExe pkgs.noctalia;
      playerctl = lib.getExe pkgs.playerctl;
      vicinae = lib.getExe' pkgs.vicinae "vicinae";
      wpctl = lib.getExe' pkgs.wireplumber "wpctl";
    in
    {
      wayland.windowManager.niri = {
        enable = true;

        systemd.enable = false;
        portalPackage = null;

        xwaylandSatellitePackage = null;

        settings = {
          prefer-no-csd = { };
          xwayland-satellite.off = { };

          input = {
            keyboard = {
              xkb = {
                inherit (config.profile.keyboard)
                  model
                  layout
                  variant
                  options
                  ;
              };
              repeat-delay = 200;
              repeat-rate = 50;
            };
            mod-key = "Super";
            mouse.accel-profile = "flat";
            warp-mouse-to-focus = { };
          };

          layout = {
            gaps = 8;
            default-column-width = { };
            focus-ring = {
              width = 2;
              active-color = config.profile.colors.gruvbox.yellow;
              inactive-color = config.profile.colors.gruvbox.bg1;
            };
          };

          hotkey-overlay.skip-at-startup = { };

          _children = [
            { spawn-at-startup = [ noctalia ]; }
            {
              spawn-at-startup = [
                (lib.getExe pkgs.swaybg)
                "--image"
                "${config.wallpaper.image}"
                "--mode"
                "fill"
              ];
            }
          ];

          binds = {
            "Mod+Return".spawn = [ ghostty ];
            "Mod+Space".spawn = [
              vicinae
              "toggle"
            ];
            "Mod+B".spawn = [ helium ];

            "Mod+Q" = {
              _props.repeat = false;
              close-window = { };
            };
            "Mod+F".maximize-column = { };
            "Mod+Shift+F".fullscreen-window = { };
            "Mod+V".toggle-window-floating = { };
            "Mod+R".switch-preset-column-width = { };
            "Mod+Shift+R".switch-preset-column-width-back = { };
            "Mod+Ctrl+R".reset-window-height = { };
            "Mod+Comma".consume-window-into-column = { };
            "Mod+Period".expel-window-from-column = { };
            "Mod+Tab" = {
              _props.repeat = false;
              toggle-overview = { };
            };

            "Mod+H".focus-column-left = { };
            "Mod+L".focus-column-right = { };
            "Mod+J".focus-window-down = { };
            "Mod+K".focus-window-up = { };
            "Mod+Shift+H".move-column-left = { };
            "Mod+Shift+L".move-column-right = { };
            "Mod+Shift+J".move-window-down = { };
            "Mod+Shift+K".move-window-up = { };

            "Mod+1".focus-workspace = 1;
            "Mod+2".focus-workspace = 2;
            "Mod+3".focus-workspace = 3;
            "Mod+4".focus-workspace = 4;
            "Mod+Shift+1".move-column-to-workspace = 1;
            "Mod+Shift+2".move-column-to-workspace = 2;
            "Mod+Shift+3".move-column-to-workspace = 3;
            "Mod+Shift+4".move-column-to-workspace = 4;

            "Print".screenshot = { };
            "Ctrl+Print".screenshot-screen = { };
            "Alt+Print".screenshot-window = { };
            "Mod+Escape" = {
              _props.allow-inhibiting = false;
              toggle-keyboard-shortcuts-inhibit = { };
            };

            "XF86AudioRaiseVolume" = {
              _props.allow-when-locked = true;
              spawn = [
                wpctl
                "set-volume"
                "@DEFAULT_AUDIO_SINK@"
                "5%+"
                "-l"
                "1.0"
              ];
            };
            "XF86AudioLowerVolume" = {
              _props.allow-when-locked = true;
              spawn = [
                wpctl
                "set-volume"
                "@DEFAULT_AUDIO_SINK@"
                "5%-"
              ];
            };
            "XF86AudioMute" = {
              _props.allow-when-locked = true;
              spawn = [
                wpctl
                "set-mute"
                "@DEFAULT_AUDIO_SINK@"
                "toggle"
              ];
            };
            "XF86AudioMicMute" = {
              _props.allow-when-locked = true;
              spawn = [
                wpctl
                "set-mute"
                "@DEFAULT_AUDIO_SOURCE@"
                "toggle"
              ];
            };
            "XF86AudioPlay" = {
              _props.allow-when-locked = true;
              spawn = [
                playerctl
                "play-pause"
              ];
            };
            "XF86AudioNext" = {
              _props.allow-when-locked = true;
              spawn = [
                playerctl
                "next"
              ];
            };
            "XF86AudioPrev" = {
              _props.allow-when-locked = true;
              spawn = [
                playerctl
                "previous"
              ];
            };
            "XF86MonBrightnessUp" = {
              _props.allow-when-locked = true;
              spawn = [
                brightnessctl
                "--class=backlight"
                "set"
                "5%+"
              ];
            };
            "XF86MonBrightnessDown" = {
              _props.allow-when-locked = true;
              spawn = [
                brightnessctl
                "--class=backlight"
                "set"
                "5%-"
              ];
            };

            "Mod+Shift+E".spawn = [
              noctalia
              "msg"
              "panel-toggle"
              "session"
            ];
            "Ctrl+Alt+Delete".quit = { };
          };
        };
      };
    };
}
