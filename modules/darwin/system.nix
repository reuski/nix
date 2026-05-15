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

      system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "64" = { enabled = false; };  # Spotlight: ⌘Space
          "65" = { enabled = false; };  # Spotlight Finder: ⌃⌘Space
          "28" = { enabled = false; };  # Screenshot to file: ⌘⇧3
          "29" = { enabled = false; };  # Area screenshot to file: ⌘⇧4
          "184" = { enabled = false; }; # Screenshot app: ⌘⇧5
        };
      };

      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      security.pam.services.sudo_local.touchIdAuth = true;
    };
}
