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
      imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];

      programs.plasma = {
        enable = true;

        workspace = {
          widgetStyle = "oxygen";
          colorScheme = "BreezeDark";
          iconTheme = "breeze";
          wallpaper = config.wallpaper.image;
          cursor = {
            theme = "Breeze";
            size = 24;
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

        hotkeys.commands.launch-ghostty = {
          key = "Meta+Return";
          command = getExe pkgs.ghostty;
        };

        krunner.shortcuts.launch = "Meta+Space";

        configFile.baloofilerc."Basic Settings"."Indexing-Enabled" = false;
      };

      home.packages = [ pkgs.kdePackages.oxygen ];
    };
}
