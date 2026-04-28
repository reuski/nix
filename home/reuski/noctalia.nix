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
              hideUnoccupied = true;
              labelMode = "index";
            }
          ];
          right = [
            { id = "Tray"; }
            { id = "WiFi"; }
            { id = "Volume"; }
            {
              id = "Battery";
              alwaysShowPercentage = true;
              warningThreshold = 20;
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
        showChangelogOnStartup = false;
      };

      idle = {
        enabled = true;
        lockTimeout = 0;
        screenOffTimeout = 180;
        suspendTimeout = 900;
        fadeDuration = 1;
      };

      location = {
        weatherEnabled = false;
      };

      controlCenter = {
        cards = [
          {
            enabled = false;
            id = "profile-card";
          }
          {
            enabled = true;
            id = "shortcuts-card";
          }
          {
            enabled = true;
            id = "audio-card";
          }
          {
            enabled = false;
            id = "brightness-card";
          }
          {
            enabled = false;
            id = "weather-card";
          }
          {
            enabled = true;
            id = "media-sysmon-card";
          }
        ];
      };

      ui.fontDefault = "Hack Nerd Font Propo";

      wallpaper.enabled = false;
    };
  };
}
