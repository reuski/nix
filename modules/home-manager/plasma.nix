{ inputs, ... }:
{
  flake.modules.homeManager.plasma =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) getExe;
    in
    {
      imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

      programs.plasma = {
        enable = true;

        workspace = {
          theme = "oxygen";
          widgetStyle = "oxygen";
          colorScheme = "BreezeDark";
          iconTheme = "breeze";
          wallpaper = config.wallpaper.images;
          cursor = {
            theme = "breeze_cursors";
            size = 24;
          };
          windowDecorations = {
            library = "org.kde.oxygen";
            theme = "Oxygen";
          };
        };

        fonts.general = {
          family = "Hack Nerd Font";
          pointSize = 11;
        };

        kwin = {
          borderlessMaximizedWindows = true;
          edgeBarrier = 0;
          cornerBarrier = false;
          virtualDesktops.number = 4;
        };

        kscreenlocker = {
          autoLock = false;
          lockOnResume = false;
        };

        powerdevil.AC = {
          autoSuspend.action = "nothing";
          turnOffDisplay.idleTimeout = 600;
        };

        hotkeys.commands.launch-ghostty = {
          key = "Meta+Return";
          command = getExe pkgs.ghostty;
        };

        krunner.shortcuts.launch = "Meta+Space";

        configFile = {
          baloofilerc."Basic Settings"."Indexing-Enabled" = false;
          kdeglobals = {
            General = {
              TerminalApplication = getExe pkgs.ghostty;
              TerminalService = "com.mitchellh.ghostty.desktop";
            };
            KDE.LookAndFeelPackage = "org.kde.oxygen";
          };
        };
      };

      gtk = {
        theme = lib.mkForce {
          package = pkgs.kdePackages.breeze-gtk;
          name = "Breeze-Dark";
        };
        iconTheme = lib.mkForce {
          package = pkgs.kdePackages.breeze-icons;
          name = "breeze";
        };
      };

      xdg.mimeApps.defaultApplications =
        let
          gwenview = "org.kde.gwenview.desktop";
          haruna = "org.kde.haruna.desktop";
        in
        {
          "image/avif" = gwenview;
          "image/gif" = gwenview;
          "image/heic" = gwenview;
          "image/jpeg" = gwenview;
          "image/png" = gwenview;
          "image/svg+xml" = gwenview;
          "image/webp" = gwenview;
          "video/mp4" = haruna;
          "video/mpeg" = haruna;
          "video/quicktime" = haruna;
          "video/webm" = haruna;
          "video/x-matroska" = haruna;
          "video/x-msvideo" = haruna;
        };

      home = {
        packages = [ pkgs.kdePackages.oxygen ];
        sessionVariables.TERMINAL = getExe pkgs.ghostty;
        pointerCursor = {
          gtk.enable = lib.mkForce true;
          package = lib.mkForce pkgs.kdePackages.breeze;
          name = lib.mkForce "breeze_cursors";
          size = lib.mkForce 24;
        };
      };
    };
}
