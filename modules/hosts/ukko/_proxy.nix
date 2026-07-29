{ config, ... }:
{
  tailnet.services = {
    hass.port = 8123;
    audiobookshelf.port = 8000;
    vaultwarden.port = 8222;
    navidrome.port = 4533;
    trek = {
      port = 3002;
      https = 8443;
    };
    ntfy = {
      port = 2586;
      https = 2587;
    };
  };

  proxy = {
    domain = "home.reuski.dev";
    dnsEnvironmentFile = config.sops.templates."acme-cloudflare-env".path;
    services = {
      adguard.port = 3000;
      attic.port = 8090;
      ntfy.port = 2586;
      vaultwarden.port = 8222;
      heimdash.domain = "home.reuski.dev";
    };
  };

  services.caddy.globalConfig = "grace_period 1m";
}
