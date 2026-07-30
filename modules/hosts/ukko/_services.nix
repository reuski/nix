{
  config,
  lib,
  pkgs,
  ...
}:
let
  tsHost = "ukko.tail2fc4c2.ts.net";
  linkdingDataDir = config.services.linkding.dataDir;
  linkdingBackup = "${linkdingDataDir}/backup.sqlite3";
  linkdingBackupTemp = "${linkdingBackup}.tmp";
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

  services.actual = {
    enable = true;
    settings = {
      hostname = "127.0.0.1";
      port = 5006;
      trustedProxies = [ "127.0.0.1/32" ];
    };
  };

  services.linkding.enable = true;

  maintainerr.enable = true;

  calibre.enable = true;

  tome.enable = true;

  trek = {
    enable = true;
    url = "https://${tsHost}:8443";
    allowedOrigins = [
      "https://${tsHost}:8443"
      "https://trek.home.reuski.dev"
    ];
    environmentFile = config.sops.templates."trek-env".path;
  };

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
      "/var/lib/private/actual"
      linkdingBackup
      "${linkdingDataDir}/assets"
      "/var/lib/valheim/saves/worlds_local"
      "/var/lib/home-assistant"
      "/var/lib/navidrome"
      "/var/lib/sonarr"
      "/var/lib/radarr"
      "/var/lib/lidarr"
      "/var/lib/prowlarr"
      "/var/lib/sabnzbd"
      "/var/lib/maintainerr"
      "/var/lib/trek/data/backups"
    ];
  };

  services.restic.backups.ukko.backupPrepareCommand = ''
    ${lib.getExe' pkgs.coreutils "rm"} -f ${linkdingBackupTemp}
    ${lib.getExe pkgs.sqlite} ${linkdingDataDir}/db.sqlite3 ".backup '${linkdingBackupTemp}'"
    ${lib.getExe' pkgs.coreutils "mv"} -f ${linkdingBackupTemp} ${linkdingBackup}
    ${lib.getExe' pkgs.coreutils "chown"} --reference=${linkdingDataDir}/db.sqlite3 ${linkdingBackup}
    ${lib.getExe' pkgs.coreutils "chmod"} --reference=${linkdingDataDir}/db.sqlite3 ${linkdingBackup}
  '';

  systemd.services.linkding-setup.serviceConfig.EnvironmentFile = lib.mkAfter [
    config.sops.templates."linkding-env".path
  ];

  systemd.services.restic-backups-ukko = {
    after = [ "linkding-setup.service" ];
    wants = [ "linkding.service" ];
  };

  hass.enable = true;

  qbittorrent = {
    enable = true;
    region = "ro";
    environmentFile = config.sops.templates."pia-gluetun-env".path;
  };

  sabnzbd.enable = true;

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
