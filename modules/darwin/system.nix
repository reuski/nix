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
          autohide-delay = 0.0;
          autohide-time-modifier = 0.2;
          show-recents = false;
          mru-spaces = false;
          tilesize = 64;
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
            "/Applications/Helium.app"
            "/Applications/Firefox Developer Edition.app"
            "/Applications/Ghostty.app"
            "/Applications/Zed.app"
            "/Users/${config.profile.username}/Applications/Slack.app"
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

      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      security.pam.services.sudo_local.touchIdAuth = true;
    };
}
