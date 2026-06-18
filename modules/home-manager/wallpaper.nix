{ ... }:
{
  flake.modules.homeManager.wallpaper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.wallpaper) primary extra;
      stems = lib.unique ([ primary ] ++ extra);
    in
    {
      options.wallpaper = {
        primary = lib.mkOption {
          type = lib.types.str;
          description = ''
            Active wallpaper stem — file name without extension, resolved against
            modules/home-manager/wallpapers/. Staged to
            ~/Pictures/Wallpapers/<primary>.png and applied by each platform's
            compositor: swaybg on Niri (home-manager/niri.nix), Finder on Darwin
            (activation below), Plasma via System Settings → Wallpaper.
          '';
        };

        extra = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional stems staged to ~/Pictures/Wallpapers/ (e.g. for a desktop wallpaper picker).";
        };
      };

      config = {
        # Single staging contract: every platform reads ~/Pictures/Wallpapers/<stem>.png.
        home.file = builtins.listToAttrs (
          map (name: {
            name = "Pictures/Wallpapers/${name}.png";
            value.source = ./wallpapers/${name}.png;
          }) stems
        );

        # Darwin has no declarative compositor; set the desktop picture post-stage.
        home.activation.wallpaper = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            /usr/bin/osascript -e 'tell app "Finder" to set desktop picture to POSIX file "${config.home.homeDirectory}/Pictures/Wallpapers/${primary}.png"' &>/dev/null || true
          ''
        );
      };
    };
}
