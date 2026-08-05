{ config, ... }:
let
  actual = config.proxy.services.actual;
in
{
  tailnet.services = {
    hass.port = 8123;
    audiobookshelf.port = 8000;
    linkding.port = config.services.linkding.port;
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
      actual = {
        domain = "actual.reuski.dev";
        port = config.services.actual.settings.port;
      };
      adguard.port = 3000;
      attic.port = 8090;
      linkding.port = config.services.linkding.port;
      ntfy.port = 2586;
      vaultwarden.port = 8222;
      heimdash.domain = "home.reuski.dev";
    };
  };

  services.caddy = {
    globalConfig = "grace_period 1m";
    virtualHosts.${actual.domain}.extraConfig = "reverse_proxy ${actual.host}:${toString actual.port}";
  };
}
