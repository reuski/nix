{ ... }:
{
  services.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = true;
        QT_QPA_PLATFORM = "wayland";
      };
    };
    settings = {
      search_files_in_root = true;
      favorites = [ ];
      fallbacks = [ "@vicinae/files:search" ];
      providers = {
        applications = {
          enabled = true;
        };
        calculator = {
          enabled = true;
        };
        files = {
          enabled = true;
        };
        wm = {
          enabled = true;
        };
        clipboard = {
          enabled = false;
        };
        core = {
          enabled = false;
        };
        developer = {
          enabled = false;
        };
        font = {
          enabled = false;
        };
        internal = {
          enabled = false;
        };
        power = {
          enabled = false;
        };
        "browser-extension" = {
          enabled = false;
        };
        "browser-tabs" = {
          enabled = false;
        };
        "raycast-compat" = {
          enabled = false;
        };
        shortcuts = {
          enabled = false;
        };
        scripts = {
          enabled = false;
        };
        shortcut = {
          enabled = false;
        };
        snippets = {
          enabled = false;
        };
        system = {
          enabled = false;
        };
        theme = {
          enabled = false;
        };
      };
      theme = {
        light = {
          name = "gruvbox-dark";
          icon_theme = "Gruvbox-Plus-Dark";
        };
        dark = {
          name = "gruvbox-dark";
          icon_theme = "Gruvbox-Plus-Dark";
        };
      };
    };
  };
}
