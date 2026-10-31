{ ... }:
{
  flake.modules.homeManager.xdg =
    { config, lib, ... }:
    {
      xdg.enable = true;
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = false;
        pictures = "${config.home.homeDirectory}/pictures";
        projects = "${config.home.homeDirectory}/projects";
        download = "${config.home.homeDirectory}/downloads";

        desktop = lib.mkDefault config.home.homeDirectory;
        documents = config.home.homeDirectory;
        templates = config.home.homeDirectory;
        music = config.home.homeDirectory;
        videos = config.home.homeDirectory;
        publicShare = config.home.homeDirectory;
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

      xdg.configFile."mimeapps.list".force = true;
    };
}
