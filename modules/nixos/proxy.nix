{ ... }:
{
  flake.modules.nixos.proxy =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.proxy;
      inherit (lib)
        concatStringsSep
        mapAttrsToList
        mkIf
        mkOption
        optionalString
        types
        unique
        ;

      tls = cfg.dnsEnvironmentFile != null;
      prefix = optionalString (!tls) "http://";
      acmeDir = "/var/lib/acme/${cfg.domain}";

      headers = ''
        header {
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          Referrer-Policy "strict-origin-when-cross-origin"
          X-Robots-Tag "noindex, nofollow"
        }
      '';

      route = name: service: ''
        @${name} host ${service.domain}
        handle @${name} {
          ${headers}
          reverse_proxy ${service.host}:${toString service.port}
        }
      '';

      routes = concatStringsSep "\n" (mapAttrsToList route cfg.services);
      domains = mapAttrsToList (_name: service: service.domain) cfg.services;
      endpoints = mapAttrsToList (_name: service: "${service.host}:${toString service.port}") cfg.services;
      site = "${prefix}${cfg.domain}, ${prefix}*.${cfg.domain}";

      tlsBlock = optionalString tls ''
        tls ${acmeDir}/fullchain.pem ${acmeDir}/key.pem
      '';

      serviceType = types.submodule (
        { name, ... }:
        {
          options = {
            domain = mkOption {
              type = types.str;
              default = "${name}.${cfg.domain}";
            };
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
            };
            port = mkOption { type = types.port; };
          };
        }
      );
    in
    {
      options.proxy = {
        domain = mkOption {
          type = types.str;
          default = "${config.networking.hostName}.home.arpa";
        };
        dnsEnvironmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
        services = mkOption {
          type = types.attrsOf serviceType;
          default = { };
        };
        openFirewall = mkOption {
          type = types.bool;
          default = true;
        };
      };

      config = mkIf (cfg.services != { }) {
        assertions = [
          {
            assertion = builtins.length domains == builtins.length (unique domains);
            message = "proxy service domains must be unique.";
          }
          {
            assertion = builtins.length endpoints == builtins.length (unique endpoints);
            message = "proxy service endpoints (host:port) must be unique.";
          }
        ];

        networking.firewall = mkIf cfg.openFirewall {
          allowedTCPPorts =
            if tls then
              [
                80
                443
              ]
            else
              [ 80 ];
          allowedUDPPorts = mkIf tls [ 443 ];
        };

        security.acme = mkIf tls {
          acceptTerms = true;
          defaults.email = config.profile.email;
          certs.${cfg.domain} = {
            extraDomainNames = [ "*.${cfg.domain}" ];
            dnsProvider = "cloudflare";
            environmentFile = cfg.dnsEnvironmentFile;
            group = config.services.caddy.group;
            reloadServices = [ "caddy.service" ];
          };
        };

        services.caddy = {
          enable = true;
          virtualHosts.${site}.extraConfig = ''
            ${tlsBlock}
            ${routes}
            handle {
              respond 404
            }
          '';
        };

        systemd.services.caddy = mkIf tls {
          after = [ "acme-finished-${cfg.domain}.target" ];
          wants = [ "acme-finished-${cfg.domain}.target" ];
        };
      };
    };
}
