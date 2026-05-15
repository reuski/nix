{ ... }:
{
  flake.modules.darwin.system =
    { config, ... }:
    {
      system.primaryUser = config.profile.username;
      system.startup.chime = false;
      time.timeZone = config.profile.timeZone;

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
          persistent-apps = [ ];
        };
        finder = {
          AppleShowAllExtensions = true;
          FXPreferredViewStyle = "clmv";
          ShowPathbar = true;
          _FXShowPosixPathInTitle = true;
        };
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
