{ ... }:
let
  disabledProviders = [
    "browser-extension"
    "browser-tabs"
    "calculator"
    "clipboard"
    "core"
    "developer"
    "font"
    "internal"
    "power"
    "raycast-compat"
    "scripts"
    "shortcuts"
    "snippets"
    "system"
    "theme"
    "wm"
  ];
in
{
  services.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      environment = {
        USE_LAYER_SHELL = true;
        QT_QPA_PLATFORM = "wayland";
      };
    };
    settings = {
      search_files_in_root = true;
      favorites = [ ];
      fallbacks = [ "files:search" ];
      providers =
        {
          applications.enabled = true;
          files = {
            enabled = true;
            entrypoints.rebuild-index.enabled = false;
          };
        }
        // builtins.listToAttrs (map (name: {
          inherit name;
          value.enabled = false;
        }) disabledProviders);
    };
  };
}
