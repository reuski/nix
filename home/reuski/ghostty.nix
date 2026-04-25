{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;
    enableFishIntegration = true;

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
      keybind = [
        "performable:ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
        "ctrl+shift+c=text:\\x03"
      ];
    };
  };
}
