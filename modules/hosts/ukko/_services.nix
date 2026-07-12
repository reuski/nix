{ config, ... }:
let
  tsHost = "ukko.tail2fc4c2.ts.net";
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      calibre-web = prev.calibre-web.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [
          "certifi"
          "chardet"
        ];
      });
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_pythonFinal: pythonPrev: {
          free-proxy = pythonPrev.free-proxy.overridePythonAttrs (old: {
            dependencies = builtins.filter (dependency: dependency.pname != "pip-chill") old.dependencies;
          });
        })
      ];
    })
  ];

  jellyfin = {
    enable = true;
    openFirewall = true;
    admin.passwordFile = config.sops.secrets."jellyfin/admin-password".path;
    libraries = [
      {
        name = "Movies";
        type = "movies";
        paths = [ "${config.media.libraryDir}/movies" ];
      }
      {
        name = "Series";
        type = "tvshows";
        paths = [ "${config.media.libraryDir}/series" ];
      }
    ];
  };
  audiobookshelf = {
    enable = true;
    libraries = [ "${config.media.libraryDir}/audiobooks" ];
  };
  navidrome = {
    enable = true;
    environmentFile = config.sops.templates."navidrome-env".path;
  };

  maintainerr.enable = true;

  calibre.enable = true;

  tome.enable = true;

  vaultwarden = {
    enable = true;
    domain = "https://${tsHost}:8222";
    environmentFile = config.sops.templates."vaultwarden-env".path;
  };
  servarr.enable = true;

  backup = {
    enable = true;
    repository = "rclone:filen:nixbackup/ukko";
    passwordFile = config.sops.secrets."backup/restic-password".path;
    rcloneConfigFile = config.sops.secrets."backup/rclone-conf".path;
    notify = "http://127.0.0.1:2586/alerts";
    stampPath = "/var/lib/heimdash/backup-stamp";
    paths = [
      "/var/backup/vaultwarden"
      "/var/lib/valheim/saves/worlds_local"
      "/var/lib/home-assistant"
      "/var/lib/navidrome"
      "/var/lib/sonarr"
      "/var/lib/radarr"
      "/var/lib/lidarr"
      "/var/lib/prowlarr"
      "/var/lib/maintainerr"
    ];
  };

  hass.enable = true;

  qbittorrent = {
    enable = true;
    region = "ro";
    environmentFile = config.sops.templates."pia-gluetun-env".path;
  };

  valheim = {
    enable = true;
    name = "Lintukoto";
    world = "Lintukoto";
    crossplay = false;
    public = true;
    statusPort = 2459;
    environmentFile = config.sops.templates."valheim-env".path;
  };

  mumble = {
    enable = true;
    environmentFile = config.sops.templates."mumble-env".path;
  };

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.home.reuski.dev";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "72h";
    };
  };
}
