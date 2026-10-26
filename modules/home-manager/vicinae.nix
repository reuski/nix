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
  flake.modules.homeManager.vicinae = { config, lib, ... }: {
    imports = [ inputs.vicinae.homeManagerModules.default ];

    systemd.user.services.vicinae.Service.ExecStart =
      lib.mkForce "${config.home.profileDirectory}/bin/vicinae server --replace";

    programs.vicinae = {
      enable = true;
      enableFirefoxIntegration = false;
      enableChromeIntegration = false;
      systemd = {
        enable = true;
        environment = {
          QT_QPA_PLATFORM = "wayland";
        };
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
  };
}
