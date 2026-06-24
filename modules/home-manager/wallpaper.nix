{ ... }:
{
  flake.modules.homeManager.wallpaper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.wallpaper = {
        primary = lib.mkOption {
          type = lib.types.str;
          description = "Active wallpaper stem in wallpapers/";
        };

        screens = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Wallpaper stems in Plasma screen order.";
        };

        image = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          description = "Resolved primary wallpaper path.";
        };

        images = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          readOnly = true;
          description = "Resolved wallpaper paths in Plasma screen order.";
        };
      };

      config = {
        wallpaper.image = ./wallpapers/${config.wallpaper.primary}.png;
        wallpaper.images =
          map (name: ./wallpapers/${name}.png) (
            if config.wallpaper.screens == [ ] then
              [ config.wallpaper.primary ]
            else
              config.wallpaper.screens
          );

        home.activation.wallpaper = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            /usr/bin/osascript -e 'tell app "Finder" to set desktop picture to POSIX file "${config.wallpaper.image}"' &>/dev/null || true
          ''
        );
      };
    };
}
