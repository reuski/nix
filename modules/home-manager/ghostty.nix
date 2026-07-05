{ ... }:
{
  flake.modules.homeManager.ghostty =
    { lib, pkgs, ... }:
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
          window-width = 140;
          window-height = 38;
          window-padding-x = 6;
          window-padding-y = 6;
          cursor-style = "bar";
          copy-on-select = true;
          keybind = [
            "ctrl+v=paste_from_clipboard"
          ]
          ++ lib.optionals isDarwin [
            "super+t=ignore"
            "ctrl+shift+two=text:@"
            "ctrl+shift+three=text:\\xc2\\xa3"
            "ctrl+shift+seven=text:|"
            "ctrl+shift+eight=text:["
            "ctrl+shift+nine=text:]"
            "ctrl+shift+e=text:\\xe2\\x82\\xac"
          ];
          confirm-close-surface = false;
          gtk-single-instance = true;
          shell-integration = "fish";
          clipboard-read = "allow";
          clipboard-write = "allow";
          shell-integration-features = "ssh-terminfo,ssh-env,sudo";
        }
        // lib.optionalAttrs isDarwin { macos-option-as-alt = true; };
      };
    };
}
