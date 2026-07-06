{ ... }:
{
  flake.modules.homeManager.ghostty =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    in
    {
      programs.ghostty = {
        enable = true;
        package = if isDarwin then null else pkgs.ghostty;

        settings = {
          font-family = "Hack Nerd Font";
          font-size = 14;
          theme = "Gruvbox Dark";
          background-opacity = 0.95;
          window-width = 140;
          window-height = 38;
          window-padding-x = 6;
          window-padding-y = 6;
          cursor-style = "bar";
          copy-on-select = true;
          keybind = [
            "ctrl+v=paste_from_clipboard"
            "super+t=ignore"
            "super+n=ignore"
            "alt+left=unbind"
            "alt+right=unbind"
          ];
          confirm-close-surface = false;
          gtk-single-instance = true;
          shell-integration = "fish";
          clipboard-read = "allow";
          clipboard-write = "allow";
          shell-integration-features = "ssh-terminfo,ssh-env,sudo";
        }
        // lib.optionalAttrs isDarwin {
          command = "/etc/profiles/per-user/${config.home.username}/bin/fish";
          macos-option-as-alt = "left";
        };
      };
    };
}
