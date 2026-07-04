{ ... }:
{
  flake.modules.darwin.system =
    { config, ... }:
    {
      system.primaryUser = config.profile.username;
      system.startup.chime = false;
      time.timeZone = config.profile.timeZone;

      documentation.enable = false;

      system.defaults = {
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          AppleShowAllExtensions = true;
          ApplePressAndHoldEnabled = false;
          KeyRepeat = 2;
          InitialKeyRepeat = 15;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          NSDocumentSaveNewDocumentsToCloud = false;
          "com.apple.swipescrolldirection" = false;
        };
        dock = {
          autohide = true;
          show-recents = false;
          mru-spaces = false;
          tilesize = 36;
          launchanim = false;
          mineffect = "scale";
          minimize-to-application = true;
          expose-group-apps = true;
          orientation = "bottom";
          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
          persistent-apps = [
            "/System/Applications/Finder.app"
            "/Applications/Ghostty.app"
            "/Applications/Firefox Developer Edition.app"
            "/Applications/Helium.app"
            "/Applications/Zed.app"
          ];
        };
        finder = {
          FXPreferredViewStyle = "clmv";
          ShowPathbar = true;
          _FXShowPosixPathInTitle = true;
          AppleShowAllFiles = true;
          _FXSortFoldersFirst = true;
          FXEnableExtensionChangeWarning = false;
          ShowStatusBar = true;
          QuitMenuItem = true;
          NewWindowTarget = "Home";
        };
        WindowManager = {
          StandardHideWidgets = true;
          StageManagerHideWidgets = true;
          GloballyEnabled = false;
          EnableStandardClickToShowDesktop = false;
        };
        controlcenter.BatteryShowPercentage = true;
        loginwindow.GuestEnabled = false;
        trackpad.Clicking = true;
      };

      system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "64" = {
            enabled = false;
          }; # Spotlight: ⌘Space
          "65" = {
            enabled = false;
          }; # Spotlight Finder: ⌃⌘Space
          "28" = {
            enabled = false;
          }; # Screenshot to file: ⌘⇧3
          "29" = {
            enabled = false;
          }; # Area screenshot to file: ⌘⇧4
          "184" = {
            enabled = false;
          }; # Screenshot app: ⌘⇧5
        };
      };

      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      security.pam.services.sudo_local.touchIdAuth = true;
    };
}
