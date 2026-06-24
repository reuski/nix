{ inputs, ... }:
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
  flake.modules.homeManager.vicinae = {
    imports = [ inputs.vicinae.homeManagerModules.default ];

    programs.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        environment = {
          USE_LAYER_SHELL = "1";
          QT_QPA_PLATFORM = "wayland";
        };
      };
      settings = {
        search_files_in_root = false;
        favorites = [ ];
        fallbacks = [ "files:search" ];
        providers = {
          applications.enabled = true;
          files = {
            enabled = true;
            entrypoints.rebuild-index.enabled = false;
          };
        }
        // builtins.listToAttrs (
          map (name: {
            inherit name;
            value.enabled = false;
          }) disabledProviders
        );
      };
    };
  };
}
