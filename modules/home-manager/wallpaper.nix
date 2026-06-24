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

        image = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          description = "Resolved wallpaper path consumed by compositor modules (niri, plasma) and the Darwin activation.";
        };
      };

      config = {
        wallpaper.image = ./wallpapers/${config.wallpaper.primary}.png;

        home.activation.wallpaper = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            /usr/bin/osascript -e 'tell app "Finder" to set desktop picture to POSIX file "${config.wallpaper.image}"' &>/dev/null || true
          ''
        );
      };
    };
}
