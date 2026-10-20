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
  bandcampDir = "${config.media.libraryDir}/bandcamp";
  bandcampStateDir = "/var/lib/bandcampsync";
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
    openFirewall = false;
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

  services.skaldi.openFirewall = false;

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

  degoog = {
    enable = true;
    environmentFile = config.sops.templates."degoog-env".path;
  };

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
      "/var/lib/jellyfin"
      "/var/lib/audiobookshelf"
      "/var/lib/bandcampsync"
      "/var/lib/navidrome"
      "/var/lib/home-assistant"
      "/var/lib/sonarr"
      "/var/lib/radarr"
      "/var/lib/lidarr"
      "/var/lib/prowlarr"
      "/var/lib/sabnzbd"
      "/var/lib/qbittorrent"
      "/var/lib/maintainerr"
      "/var/lib/calibre-web"
      "/var/lib/tome"
      "/var/lib/degoog"
      "/var/lib/trek/data"
      "/var/lib/trek/uploads"
      "/var/lib/valheim/backups"
    ];
  };

  services.restic.backups.ukko = {
    exclude = [
      "/var/lib/degoog/indexer"
      "${config.media.libraryDir}/torrents"
      "${config.media.libraryDir}/usenet/incomplete"
      "${config.media.libraryDir}/usenet/complete"
    ];
    backupPrepareCommand = ''
      ${lib.getExe' pkgs.coreutils "rm"} -f ${linkdingBackupTemp}
      ${lib.getExe pkgs.sqlite} ${linkdingDataDir}/db.sqlite3 ".backup '${linkdingBackupTemp}'"
      ${lib.getExe' pkgs.coreutils "mv"} -f ${linkdingBackupTemp} ${linkdingBackup}
      ${lib.getExe' pkgs.coreutils "chown"} --reference=${linkdingDataDir}/db.sqlite3 ${linkdingBackup}
      ${lib.getExe' pkgs.coreutils "chmod"} --reference=${linkdingDataDir}/db.sqlite3 ${linkdingBackup}
    '';
  };

  systemd.services.linkding-setup.serviceConfig.EnvironmentFile = lib.mkAfter [
    config.sops.templates."linkding-env".path
  ];

  systemd.services.restic-backups-ukko = {
    after = [ "linkding-setup.service" ];
    wants = [ "linkding.service" ];
  };

  systemd.services.bandcampsync = {
    description = "Sync Bandcamp purchases into the Lidarr import staging dir";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = config.media.user;
      Group = config.media.group;
      UMask = "0002";
      TimeoutStartSec = "6h";
      ExecStartPre = "${lib.getExe' pkgs.coreutils "touch"} ${bandcampStateDir}/ignores.txt";
      ExecStart = "${lib.getExe pkgs.bandcampsync} --cookies ${
        config.sops.secrets."bandcamp/cookies".path
      } --directory ${bandcampDir} --ignore-file ${bandcampStateDir}/ignores.txt --skip-item-index --temp-dir ${bandcampDir}/.tmp";
    };
  };

  systemd.timers.bandcampsync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  media.directories = {
    ${bandcampDir} = { };
    "${bandcampDir}/.tmp" = {
      mode = "0700";
    };
    ${bandcampStateDir} = {
      mode = "0750";
    };
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
    modifiers = {
      resources = "more";
      deathpenalty = "casual";
      portals = "casual";
      raids = "muchless";
    };
    saveInterval = 600;
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
