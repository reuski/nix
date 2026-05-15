{ ... }:
{
  flake.modules.homeManager.ghostty =
    { pkgs, ... }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    in
    {
      programs.ghostty = {
        enable = true;
        package = if isDarwin then null else pkgs.ghostty;
        enableFishIntegration = !isDarwin;

        settings = {
          font-family = "Hack Nerd Font";
          font-size = 12;
          theme = "Gruvbox Dark";
          background-opacity = 0.95;
          window-padding-x = 6;
          window-padding-y = 6;
          cursor-style = "bar";
          copy-on-select = true;
          confirm-close-surface = false;
          gtk-single-instance = true;
          window-decoration = false;
          shell-integration = "fish";
          clipboard-read = "allow";
          clipboard-write = "allow";
        };
      };
    };
}
