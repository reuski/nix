{ ... }:
{
  flake.modules.homeManager.xdg =
    { config, ... }:
    {
      xdg.enable = true;
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = true;
        pictures = "${config.profile.homeDirectory}/pictures";
        projects = "${config.profile.homeDirectory}/projects";
        documents = null;
        download = "${config.profile.homeDirectory}/downloads";
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

      xdg.configFile."mimeapps.list".force = true;
    };
}
