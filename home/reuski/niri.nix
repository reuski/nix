{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  noctaliaPackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  vicinaePackage = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
  noctalia =
    cmd:
    [
      "${noctaliaPackage}/bin/noctalia-shell"
      "ipc"
      "call"
    ]
    ++ (lib.splitString " " cmd);
in
{
  programs.niri.settings = {
    prefer-no-csd = true;

    environment = {
      DISPLAY = ":0";
      QT_QPA_PLATFORM = "wayland;xcb";
    };

    input = {
      keyboard.xkb = {
        layout = "fi";
        variant = "nodeadkeys";
        options = "ctrl:nocaps";
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
        accel-profile = "adaptive";
        click-method = "clickfinger";
        scroll-method = "two-finger";
      };
      trackpoint = {
        accel-profile = "flat";
        accel-speed = 0.0;
      };
      mouse.accel-profile = "flat";
      warp-mouse-to-focus.enable = true;
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

    layout = {
      gaps = 8;
      center-focused-column = "never";
      preset-column-widths = [
        { proportion = 1.0 / 3.0; }
        { proportion = 0.5; }
        { proportion = 2.0 / 3.0; }
        { proportion = 1.0; }
      ];
      default-column-width = {
        proportion = 0.5;
      };
      focus-ring = {
        enable = true;
        width = 2;
        active.color = "#fabd2f";
        inactive.color = "#3c3836";
      };
      border.enable = false;
    };

    spawn-at-startup = [
      { command = [ (lib.getExe' pkgs.xwayland-satellite-unstable "xwayland-satellite") ]; }
      { command = [ "${noctaliaPackage}/bin/noctalia-shell" ]; }
    ];

    binds = {
      "Mod+Return".action.spawn = lib.getExe pkgs.ghostty;
      "Mod+D".action.spawn = [
        (lib.getExe' vicinaePackage "vicinae")
        "toggle"
      ];
      "Mod+B".action.spawn = lib.getExe pkgs.helium-browser;

      "Mod+Q".action.close-window = [ ];
      "Mod+F".action.maximize-column = [ ];
      "Mod+Shift+F".action.fullscreen-window = [ ];
      "Mod+V".action.toggle-window-floating = [ ];
      "Mod+R".action.switch-preset-column-width = [ ];
      "Mod+Shift+R".action.reset-window-height = [ ];
      "Mod+Comma".action.consume-window-into-column = [ ];
      "Mod+Period".action.expel-window-from-column = [ ];
      "Mod+Tab".action.toggle-overview = [ ];

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
      "Mod+5".action.focus-workspace = 5;
      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;
      "Mod+Shift+5".action.move-column-to-workspace = 5;

      "Print".action.screenshot = [ ];
      "Ctrl+Print".action.screenshot-screen = [ ];
      "Alt+Print".action.screenshot-window = [ ];

      "XF86AudioRaiseVolume".action.spawn = [
        wpctl
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%+"
      ];
      "XF86AudioLowerVolume".action.spawn = [
        wpctl
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%-"
      ];
      "XF86AudioMute".action.spawn = [
        wpctl
        "set-mute"
        "@DEFAULT_AUDIO_SINK@"
        "toggle"
      ];
      "XF86AudioMicMute".action.spawn = [
        wpctl
        "set-mute"
        "@DEFAULT_AUDIO_SOURCE@"
        "toggle"
      ];
      "XF86AudioPlay".action.spawn = [
        (lib.getExe pkgs.playerctl)
        "play-pause"
      ];
      "XF86AudioNext".action.spawn = [
        (lib.getExe pkgs.playerctl)
        "next"
      ];
      "XF86AudioPrev".action.spawn = [
        (lib.getExe pkgs.playerctl)
        "previous"
      ];
      "XF86MonBrightnessUp".action.spawn = [
        (lib.getExe pkgs.brightnessctl)
        "s"
        "5%+"
      ];
      "XF86MonBrightnessDown".action.spawn = [
        (lib.getExe pkgs.brightnessctl)
        "s"
        "5%-"
      ];

      "Mod+Shift+E".action.spawn = noctalia "sessionMenu toggle";
      "Mod+Shift+Q".action.quit = [ ];
    };
  };
}
