{ ... }:
{
  flake.modules.homeManager.gtk =
    { pkgs, ... }:
    let
      gruvboxDarkGtkTheme = {
        package = pkgs.gruvbox-gtk-theme;
        name = "Gruvbox-Dark";
      };
    in
    {
      gtk = {
        enable = true;
        colorScheme = "dark";
        gtk2.enable = false;
        theme = gruvboxDarkGtkTheme;
        gtk4.theme = null;
        iconTheme = {
          package = pkgs.gruvbox-plus-icons;
          name = "Gruvbox-Plus-Dark";
        };
        font = {
          name = "Inter";
          size = 10;
        };
      };

      home.pointerCursor = {
        gtk.enable = true;
        package = pkgs.graphite-cursors;
        name = "graphite-dark";
        size = 24;
      };
    };
}
