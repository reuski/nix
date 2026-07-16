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
    in
    {
      imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

      programs.plasma = {
        enable = true;

        input.keyboard = {
          layouts = [
            { inherit (config.profile.keyboard) layout variant; }
          ];
          model = config.profile.keyboard.model;
          options =
            let
              o = config.profile.keyboard.options;
            in
            if o == "" then [ ] else lib.splitString "," o;
        };

        workspace = {
          colorScheme = "OxygenDark";
          theme = "oxygen";
          widgetStyle = "Union";
          windowDecorations = {
            library = "org.kde.kwin.aurorae";
            theme = "kwin4_decoration_qml_plastik";
          };
          splashScreen.theme = "None";
          cursor = {
            theme = "Oxygen_Zion";
            size = 24;
          };
          iconTheme = "breeze-dark";
          wallpaper = config.wallpaper.images;
        };

        fonts = {
          general = {
            family = "Inter";
            pointSize = 10;
          };
          fixedWidth = {
            family = "Hack Nerd Font";
            pointSize = 10;
          };
          small = {
            family = "Inter";
            pointSize = 8;
          };
          windowTitle = {
            family = "Inter";
            pointSize = 10;
            weight = "demiBold";
          };
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
        shortcuts.plasmashell."manage activities" = [ ];

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
            accentColorFromWallpaper = true;
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
        packages = [
          pkgs.kdePackages.oxygen
          pkgs.kdePackages.union
        ];
        sessionVariables.TERMINAL = getExe pkgs.ghostty;
      };
    };
}
