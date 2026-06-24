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

        configFile.baloofilerc."Basic Settings"."Indexing-Enabled" = false;
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

      home = {
        packages = [ pkgs.kdePackages.oxygen ];
        pointerCursor = {
          gtk.enable = lib.mkForce true;
          package = lib.mkForce pkgs.kdePackages.breeze;
          name = lib.mkForce "breeze_cursors";
          size = lib.mkForce 24;
        };
      };
    };
}
