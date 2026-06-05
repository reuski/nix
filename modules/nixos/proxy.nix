{ ... }:
{
  flake.modules.nixos.proxy =
    {
      config,
      lib,
      pkgs,
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
      site = "${prefix}${cfg.domain}, ${prefix}*.${cfg.domain}";

      tlsBlock = optionalString tls ''
        tls {
          dns cloudflare {env.CF_API_TOKEN}
        }
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
        ];

        networking.firewall = mkIf cfg.openFirewall {
          allowedTCPPorts = if tls then [ 80 443 ] else [ 80 ];
          allowedUDPPorts = mkIf tls [ 443 ];
        };

        services.caddy = {
          enable = true;
          email = mkIf tls config.profile.email;
          package = mkIf tls (
            pkgs.caddy.withPlugins {
              plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
              hash = lib.fakeHash;
            }
          );
          virtualHosts.${site}.extraConfig = ''
            ${tlsBlock}
            ${routes}
            handle {
              respond 404
            }
          '';
        };

        systemd.services.caddy.serviceConfig.EnvironmentFile = mkIf tls cfg.dnsEnvironmentFile;
      };
    };
}
