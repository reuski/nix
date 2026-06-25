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
      inherit (lib) genAttrs getExe;
      cursorTheme = "breeze_cursors";
      cursorSize = 24;
    in
    {
      imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

      programs.plasma = {
        enable = true;

        workspace = {
          theme = "breeze-dark";
          widgetStyle = "oxygen";
          colorScheme = "BreezeDark";
          iconTheme = "breeze-dark";
          wallpaper = config.wallpaper.images;
          cursor = {
            theme = cursorTheme;
            size = cursorSize;
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

        shortcuts.kwin."Window Close" = "Meta+Q";

        krunner.shortcuts.launch = "Meta+Space";

        configFile = {
          kwalletrc.Wallet = {
            Enabled = true;
            "Default Wallet" = "Default";
            "Close When Idle" = false;
          };
          baloofilerc."Basic Settings"."Indexing-Enabled" = false;
          kdeglobals.General = {
            TerminalApplication = getExe pkgs.ghostty;
            TerminalService = "com.mitchellh.ghostty.desktop";
          };
          kdeglobals.Sounds.Enable = false;
        };
      };

      gtk = {
        enable = true;
        gtk2.enable = false;
        theme = {
          package = pkgs.kdePackages.breeze-gtk;
          name = "Breeze-Dark";
        };
        iconTheme = {
          package = pkgs.kdePackages.breeze-icons;
          name = "breeze-dark";
        };
      };

      xdg.mimeApps.defaultApplications =
        let
          gwenview = "org.kde.gwenview.desktop";
          haruna = "org.kde.haruna.desktop";
          imageTypes = [
            "image/avif"
            "image/gif"
            "image/heic"
            "image/jpeg"
            "image/png"
            "image/svg+xml"
            "image/webp"
          ];
          videoTypes = [
            "video/mp4"
            "video/mpeg"
            "video/quicktime"
            "video/webm"
            "video/x-matroska"
            "video/x-msvideo"
          ];
        in
        genAttrs imageTypes (_: gwenview) // genAttrs videoTypes (_: haruna);

      home = {
        packages = [ pkgs.kdePackages.oxygen ];
        sessionVariables.TERMINAL = getExe pkgs.ghostty;
        pointerCursor = {
          gtk.enable = true;
          package = pkgs.kdePackages.breeze;
          name = cursorTheme;
          size = cursorSize;
        };
      };
    };
}
