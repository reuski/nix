{ config, ... }:
{
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;
    pictures = "${config.home.homeDirectory}/Pictures";
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    desktop = null;
    templates = null;
    music = null;
    videos = null;
    publicShare = null;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        h = "helium-browser.desktop";
      in
      {
        "text/html" = h;
        "application/xhtml+xml" = h;
        "x-scheme-handler/http" = h;
        "x-scheme-handler/https" = h;
        "x-scheme-handler/about" = h;
        "x-scheme-handler/unknown" = h;
        "x-scheme-handler/chrome" = h;
      };
  };
}
