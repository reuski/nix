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
