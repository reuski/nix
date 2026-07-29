{
  config,
  lib,
  ...
}:
let
  inherit (lib) optionalAttrs;

  card =
    key:
    {
      name,
      kind ? null,
      checkPath ? null,
      credential ? null,
      entity ? null,
      stamp ? null,
      urlPath ? "",
    }:
    let
      p = config.proxy.services.${key};
      origin = "https://${p.domain}";
    in
    {
      inherit name kind;
      url = "${origin}${urlPath}";
      api = "http://${p.host}:${toString p.port}";
    }
    // optionalAttrs (checkPath != null) { check = "${origin}${checkPath}"; }
    // optionalAttrs (credential != null) { inherit credential; }
    // optionalAttrs (entity != null) { inherit entity; }
    // optionalAttrs (stamp != null) { inherit stamp; };
in
{
  services.heimdash = {
    enable = true;
    mounts = [
      "/"
      "/srv/media"
    ];
    credentials = {
      sonarr-api-key.path = config.sops.secrets."sonarr/api-key".path;
      radarr-api-key.path = config.sops.secrets."radarr/api-key".path;
      lidarr-api-key.path = config.sops.secrets."lidarr/api-key".path;
      prowlarr-api-key.path = config.sops.secrets."prowlarr/api-key".path;
      jellyfin-api-key.path = config.sops.secrets."jellyfin/api-key".path;
      audiobookshelf-api-key.path = config.sops.secrets."audiobookshelf/api-key".path;
      qbittorrent-api-key.path = config.sops.secrets."qbittorrent/api-key".path;
      home-assistant-token.path = config.sops.secrets."home-assistant/token".path;
      vaultwarden-admin-token.path = config.sops.secrets."vaultwarden/admin-token".path;
      calibre-credentials.path = config.sops.secrets."calibre/credentials".path;
      navidrome-credentials.path = config.sops.templates."navidrome-heimdash-credentials".path;
    };
    services = [
      (card "actual" {
        name = "Actual Budget";
        checkPath = "/health";
      })
      (card "linkding" {
        name = "Linkding";
        checkPath = "/health";
      })
      (card "adguard" {
        name = "AdGuard";
        kind = "adguard";
        checkPath = "/login.html";
      })
      (card "hass" {
        name = "Home Assistant";
        kind = "home_assistant";
        credential = "home-assistant-token";
        entity = "weather.forecast_home";
      })
      (card "qbittorrent" {
        name = "qBittorrent";
        kind = "qbittorrent";
        credential = "qbittorrent-api-key";
      })
      (card "jellyfin" {
        name = "Jellyfin";
        kind = "jellyfin";
        checkPath = "/System/Info/Public";
        credential = "jellyfin-api-key";
      })
      (card "maintainerr" {
        name = "Maintainerr";
        kind = "maintainerr";
        checkPath = "/api/health/ready";
      })
      (card "audiobookshelf" {
        name = "Audiobookshelf";
        kind = "audiobookshelf";
        checkPath = "/healthcheck";
        credential = "audiobookshelf-api-key";
      })
      (card "skaldi" {
        name = "Skaldi";
        kind = "skaldi";
      })
      (card "navidrome" {
        name = "Navidrome";
        kind = "navidrome";
        checkPath = "";
        credential = "navidrome-credentials";
      })
      (card "calibre" {
        name = "Calibre";
        kind = "calibre";
        credential = "calibre-credentials";
      })
      (card "tome" {
        name = "Tome";
        kind = "tome";
        checkPath = "";
      })
      (card "trek" {
        name = "TREK";
        kind = "trek";
        checkPath = "/api/health";
      })
      (card "valheim" {
        name = "Valheim";
        kind = "valheim";
        checkPath = "/health";
      })
      {
        name = "Mumble";
        url = "mumble://mumble.reuski.dev";
        api = "udp://127.0.0.1:64738";
        kind = "mumble";
      }
      (card "sonarr" {
        name = "Sonarr";
        kind = "sonarr";
        checkPath = "/ping";
        credential = "sonarr-api-key";
      })
      (card "radarr" {
        name = "Radarr";
        kind = "radarr";
        checkPath = "/ping";
        credential = "radarr-api-key";
      })
      (card "lidarr" {
        name = "Lidarr";
        kind = "lidarr";
        checkPath = "/ping";
        credential = "lidarr-api-key";
      })
      (card "prowlarr" {
        name = "Prowlarr";
        kind = "prowlarr";
        checkPath = "/ping";
        credential = "prowlarr-api-key";
      })
      (card "vaultwarden" {
        name = "Vaultwarden";
        kind = "vaultwarden";
        checkPath = "/alive";
        credential = "vaultwarden-admin-token";
      })
      (card "attic" {
        name = "Attic";
        kind = "attic";
        checkPath = "/ukko/nix-cache-info";
        urlPath = "/ukko";
        stamp = "/var/lib/heimdash/attic-primed";
      })
      {
        name = "Backup";
        url = "https://drive.filen.io";
        kind = "backup";
        stamp = "/var/lib/heimdash/backup-stamp";
      }
      {
        name = "ntfy";
        url = "https://ntfy.home.reuski.dev";
        check = "http://127.0.0.1:2586/v1/health";
        api = "http://127.0.0.1:2586/updates,alerts";
        kind = "ntfy";
      }
    ];
  };
}
