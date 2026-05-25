{ ... }:
{
  flake.modules.nixos.proxy =
    { config, lib, ... }:
    let
      cfg = config.proxy;
      inherit (lib)
        mapAttrs'
        mapAttrsToList
        mkIf
        mkOption
        nameValuePair
        optionalString
        types
        unique
        ;

      serviceType = types.submodule (
        { name, ... }:
        {
          options = {
            domain = mkOption {
              type = types.str;
              default = "${name}.${cfg.domain}";
            };
            listen = mkOption {
              type = types.port;
              default = 80;
            };
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
            };
            port = mkOption { type = types.port; };
          };
        }
      );

      address =
        service:
        "http://${service.domain}${optionalString (service.listen != 80) ":${toString service.listen}"}";

      headers = ''
        header {
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          Referrer-Policy "strict-origin-when-cross-origin"
          X-Robots-Tag "noindex, nofollow"
        }
      '';

      serviceHost =
        _name: service:
        nameValuePair (address service) {
          extraConfig = ''
            ${headers}
            reverse_proxy ${service.host}:${toString service.port}
          '';
        };

      hosts = mapAttrsToList (_name: service: address service) cfg.services;
      ports = mapAttrsToList (_name: service: service.listen) cfg.services;
    in
    {
      options.proxy = {
        domain = mkOption {
          type = types.str;
          default = "${config.networking.hostName}.home.arpa";
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
            assertion = builtins.length hosts == builtins.length (unique hosts);
            message = "proxy hosts must be unique.";
          }
        ];

        networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (unique ports);

        services.caddy = {
          enable = true;
          virtualHosts = mapAttrs' serviceHost cfg.services;
        };
      };
    };
}
