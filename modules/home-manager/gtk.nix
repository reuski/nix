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
        theme = gruvboxDarkGtkTheme;
        gtk4.theme = null;
        iconTheme = {
          package = pkgs.gruvbox-plus-icons;
          name = "Gruvbox-Plus-Dark";
        };
        font = {
          name = "Inter";
          size = 11;
        };
      };

      home.pointerCursor = {
        gtk.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };
    };
}
