{ ... }:
{
  flake.modules.homeManager.ghostty =
    { pkgs, ... }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      multiplexerConflicts =
        if isDarwin then
          [
            "cmd+t=unbind"
            "cmd+d=unbind"
            "cmd+shift+d=unbind"
          ]
        else
          [ "ctrl+shift+t=unbind" ];
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
          keybind = [ "ctrl+v=paste_from_clipboard" ] ++ multiplexerConflicts;
          confirm-close-surface = false;
          gtk-single-instance = true;
          shell-integration = "fish";
          clipboard-read = "allow";
          clipboard-write = "allow";
          shell-integration-features = "ssh-terminfo,ssh-env,sudo";
        };
      };
    };
}
