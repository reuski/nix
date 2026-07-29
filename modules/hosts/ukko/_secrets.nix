{
  config,
  lib,
  ...
}:
{
  sops.secrets = {
    "backup/restic-password".restartUnits = [ "restic-backups-ukko.service" ];
    "backup/rclone-conf".restartUnits = [ "restic-backups-ukko.service" ];
    "cloudflare/dns-token".restartUnits = [ "cloudflare-dyndns.service" ];
    "jellyfin/admin-password".restartUnits = [ "jellyfin-setup.service" ];
    "pia/username".restartUnits = [ "gluetun.service" ];
    "pia/password".restartUnits = [ "gluetun.service" ];
    "valheim/password".restartUnits = [ "valheim.service" ];
    "mumble/password".restartUnits = [ "murmur.service" ];
    "trek/encryption-key".restartUnits = [ "trek.service" ];
    "navidrome/admin-password".restartUnits = [
      "navidrome.service"
      "skaldi.service"
    ];
  }
  //
    lib.genAttrs
      [
        "audiobookshelf/api-key"
        "calibre/credentials"
        "home-assistant/token"
        "jellyfin/api-key"
        "lidarr/api-key"
        "prowlarr/api-key"
        "qbittorrent/api-key"
        "radarr/api-key"
        "sonarr/api-key"
        "vaultwarden/admin-token"
      ]
      (_: {
        restartUnits = [ "heimdash.service" ];
      });

  sops.templates = {
    "acme-cloudflare-env" = {
      content = "CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/dns-token"}";
      restartUnits = [ "acme-home.reuski.dev.service" ];
    };
    "vaultwarden-env" = {
      content = "ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin-token"}";
      restartUnits = [ "vaultwarden.service" ];
    };
    "valheim-env" = {
      content = "PASSWORD=${config.sops.placeholder."valheim/password"}";
      restartUnits = [ "valheim.service" ];
    };
    "mumble-env" = {
      content = "MUMBLE_PASSWORD=${config.sops.placeholder."mumble/password"}";
      restartUnits = [ "murmur.service" ];
    };
    "navidrome-env" = {
      content = "ND_DEVAUTOCREATEADMINPASSWORD=${config.sops.placeholder."navidrome/admin-password"}";
      restartUnits = [ "navidrome.service" ];
    };
    "trek-env" = {
      content = "ENCRYPTION_KEY=${config.sops.placeholder."trek/encryption-key"}";
      restartUnits = [ "trek.service" ];
    };
    "navidrome-heimdash-credentials" = {
      content = "admin:${config.sops.placeholder."navidrome/admin-password"}";
      restartUnits = [ "heimdash.service" ];
    };
    "pia-gluetun-env" = {
      content = ''
        PIA_USER="${config.sops.placeholder."pia/username"}"
        PIA_PASS="${config.sops.placeholder."pia/password"}"
        VPN_PORT_FORWARDING_USERNAME="${config.sops.placeholder."pia/username"}"
        VPN_PORT_FORWARDING_PASSWORD="${config.sops.placeholder."pia/password"}"
      '';
      restartUnits = [ "gluetun.service" ];
    };
  };
}
