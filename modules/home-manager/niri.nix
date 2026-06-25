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
      noctalia = lib.getExe pkgs.noctalia;
      playerctl = lib.getExe pkgs.playerctl;
      vicinae = lib.getExe' pkgs.vicinae "vicinae";
      wpctl = lib.getExe' pkgs.wireplumber "wpctl";
    in
    {
      programs.niri.settings = {
        prefer-no-csd = true;
        xwayland-satellite.enable = false;

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
          warp-mouse-to-focus.enable = true;
        };

        layout = {
          gaps = 8;
          focus-ring = {
            width = 2;
            active.color = config.profile.colors.gruvbox.yellow;
            inactive.color = config.profile.colors.gruvbox.bg1;
          };
        };

        hotkey-overlay.skip-at-startup = true;

        spawn-at-startup = [
          { command = [ noctalia ]; }
          {
            command = [
              (lib.getExe pkgs.swaybg)
              "--image"
              "${config.wallpaper.image}"
              "--mode"
              "fill"
            ];
          }
        ];

        binds = {
          "Mod+Return".action.spawn = ghostty;
          "Mod+Space".action.spawn = [
            vicinae
            "toggle"
          ];
          "Mod+B".action.spawn = lib.getExe pkgs.helium-browser;

          "Mod+Q" = {
            repeat = false;
            action.close-window = [ ];
          };
          "Mod+F".action.maximize-column = [ ];
          "Mod+Shift+F".action.fullscreen-window = [ ];
          "Mod+V".action.toggle-window-floating = [ ];
          "Mod+R".action.switch-preset-column-width = [ ];
          "Mod+Shift+R".action.switch-preset-column-width-back = [ ];
          "Mod+Ctrl+R".action.reset-window-height = [ ];
          "Mod+Comma".action.consume-window-into-column = [ ];
          "Mod+Period".action.expel-window-from-column = [ ];
          "Mod+Tab" = {
            repeat = false;
            action.toggle-overview = [ ];
          };

          "Mod+H".action.focus-column-left = [ ];
          "Mod+L".action.focus-column-right = [ ];
          "Mod+J".action.focus-window-down = [ ];
          "Mod+K".action.focus-window-up = [ ];
          "Mod+Shift+H".action.move-column-left = [ ];
          "Mod+Shift+L".action.move-column-right = [ ];
          "Mod+Shift+J".action.move-window-down = [ ];
          "Mod+Shift+K".action.move-window-up = [ ];

          "Mod+1".action.focus-workspace = 1;
          "Mod+2".action.focus-workspace = 2;
          "Mod+3".action.focus-workspace = 3;
          "Mod+4".action.focus-workspace = 4;
          "Mod+Shift+1".action.move-column-to-workspace = 1;
          "Mod+Shift+2".action.move-column-to-workspace = 2;
          "Mod+Shift+3".action.move-column-to-workspace = 3;
          "Mod+Shift+4".action.move-column-to-workspace = 4;

          "Print".action.screenshot = [ ];
          "Ctrl+Print".action.screenshot-screen = [ ];
          "Alt+Print".action.screenshot-window = [ ];
          "Mod+Escape" = {
            allow-inhibiting = false;
            action.toggle-keyboard-shortcuts-inhibit = [ ];
          };

          "XF86AudioRaiseVolume" = {
            allow-when-locked = true;
            action.spawn = [
              wpctl
              "set-volume"
              "@DEFAULT_AUDIO_SINK@"
              "5%+"
              "-l"
              "1.0"
            ];
          };
          "XF86AudioLowerVolume" = {
            allow-when-locked = true;
            action.spawn = [
              wpctl
              "set-volume"
              "@DEFAULT_AUDIO_SINK@"
              "5%-"
            ];
          };
          "XF86AudioMute" = {
            allow-when-locked = true;
            action.spawn = [
              wpctl
              "set-mute"
              "@DEFAULT_AUDIO_SINK@"
              "toggle"
            ];
          };
          "XF86AudioMicMute" = {
            allow-when-locked = true;
            action.spawn = [
              wpctl
              "set-mute"
              "@DEFAULT_AUDIO_SOURCE@"
              "toggle"
            ];
          };
          "XF86AudioPlay" = {
            allow-when-locked = true;
            action.spawn = [
              playerctl
              "play-pause"
            ];
          };
          "XF86AudioNext" = {
            allow-when-locked = true;
            action.spawn = [
              playerctl
              "next"
            ];
          };
          "XF86AudioPrev" = {
            allow-when-locked = true;
            action.spawn = [
              playerctl
              "previous"
            ];
          };
          "XF86MonBrightnessUp" = {
            allow-when-locked = true;
            action.spawn = [
              brightnessctl
              "--class=backlight"
              "set"
              "5%+"
            ];
          };
          "XF86MonBrightnessDown" = {
            allow-when-locked = true;
            action.spawn = [
              brightnessctl
              "--class=backlight"
              "set"
              "5%-"
            ];
          };

          "Mod+Shift+E".action.spawn = [
            noctalia
            "msg"
            "panel-toggle"
            "session"
          ];
          "Ctrl+Alt+Delete".action.quit = [ ];
        };
      };
    };
}
