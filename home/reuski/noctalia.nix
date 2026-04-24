{ ... }:
{
  programs.noctalia-shell = {
    enable = true;

    settings = {
      bar = {
        position = "top";
        density = "compact";
        backgroundOpacity = 0.92;
        widgets = {
          left = [
            {
              id = "ActiveWindow";
              showIcon = true;
              maxWidth = 320;
            }
            {
              id = "MediaMini";
              maxWidth = 220;
            }
          ];
          center = [
            {
              id = "Workspace";
              hideUnoccupied = false;
              labelMode = "index";
            }
          ];
          right = [
            { id = "Tray"; }
            { id = "WiFi"; }
            { id = "Bluetooth"; }
            { id = "Volume"; }
            {
              id = "Battery";
              alwaysShowPercentage = true;
              warningThreshold = 20;
            }
            {
              id = "Clock";
              formatHorizontal = "HH:mm";
              useMonospacedFont = true;
            }
            {
              id = "ControlCenter";
              useDistroLogo = true;
            }
          ];
        };
      };

      colorSchemes = {
        darkMode = true;
        predefinedScheme = "Gruvbox";
      };

      general = {
        radiusRatio = 0.2;
        compactLockScreen = true;
        lockOnSuspend = false;
        autoStartAuth = true;
        allowPasswordWithFprintd = true;
      };

      idle = {
        enabled = true;
        lockTimeout = 0;
        screenOffTimeout = 180;
        suspendTimeout = 900;
        fadeDuration = 3;
      };

      location = {
        name = "Helsinki";
        monthBeforeDay = false;
      };

      ui.fontDefault = "Hack Nerd Font Propo";

      wallpaper.enabled = false;
    };
  };
}
