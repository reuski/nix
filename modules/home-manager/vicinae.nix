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
    "kde-settings"
    "media"
    "power"
    "raycast-compat"
    "screenshots"
    "scripts"
    "shortcuts"
    "snippets"
    "system"
    "theme"
    "wm"
  ];
in
{
  flake.modules.homeManager.vicinae =
    { lib, pkgs, ... }:
    {
      programs.vicinae = {
        enable = true;
        enableFirefoxIntegration = false;
        systemd = {
          enable = true;
        };
        settings = {
          search_files_in_root = false;
          pop_to_root_on_close = true;
          input_server.enabled = false;
          tray.enabled = false;
          launcher_window.clock.enabled = false;
          telemetry.system_info = false;
          updates.show_notice = false;
          favorites = [ ];
          fallbacks = [ "files:search" ];
          providers = {
            applications.enabled = true;
            files.enabled = true;
          }
          // builtins.listToAttrs (
            map (name: {
              inherit name;
              value.enabled = false;
            }) disabledProviders
          );
        };
      };

      systemd.user.services.vicinae.Service = {
        ExecStart = lib.mkForce "${lib.getExe pkgs.vicinae} server --replace";
        Environment = [ "\"QT_QPA_PLATFORM=wayland\"" ];
      };
    };
}
