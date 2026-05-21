{ ... }:
{
  flake.modules.nixos.proxy =
    { config, lib, ... }:
    let
      cfg = config.proxy;
      inherit (lib)
        concatLists
        mapAttrs'
        mapAttrsToList
        mkIf
        mkOption
        nameValuePair
        optionalString
        types
        unique
        ;

      hostOptions = name: {
        domain = mkOption {
          type = types.str;
          default = "${name}.${cfg.domain}";
        };
        listen = mkOption {
          type = types.port;
          default = 80;
        };
      };

      serviceType = types.submodule (
        { name, ... }:
        {
          options = hostOptions name // {
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
            };
            port = mkOption { type = types.port; };
          };
        }
      );

      siteType = types.submodule (
        { name, ... }:
        {
          options = hostOptions name // {
            root = mkOption { type = types.str; };
          };
        }
      );

      address =
        host: "http://${host.domain}${optionalString (host.listen != 80) ":${toString host.listen}"}";

      serviceHost =
        _name: service:
        nameValuePair (address service) {
          extraConfig = "reverse_proxy ${service.host}:${toString service.port}";
        };

      siteHost =
        _name: site:
        nameValuePair (address site) {
          extraConfig = ''
            root * ${site.root}
            file_server
          '';
        };

      hosts = concatLists [
        (mapAttrsToList (_name: service: address service) cfg.services)
        (mapAttrsToList (_name: site: address site) cfg.sites)
      ];
      ports = concatLists [
        (mapAttrsToList (_name: service: service.listen) cfg.services)
        (mapAttrsToList (_name: site: site.listen) cfg.sites)
      ];
      enabled = cfg.services != { } || cfg.sites != { };
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
        sites = mkOption {
          type = types.attrsOf siteType;
          default = { };
        };
        openFirewall = mkOption {
          type = types.bool;
          default = true;
        };
      };

      config = mkIf enabled {
        assertions = [
          {
            assertion = builtins.length hosts == builtins.length (unique hosts);
            message = "proxy hosts must be unique.";
          }
        ];

        networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (unique ports);

        services.caddy = {
          enable = true;
          virtualHosts = mapAttrs' serviceHost cfg.services // mapAttrs' siteHost cfg.sites;
        };
      };
    };
}
