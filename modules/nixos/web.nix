{ ... }:
{
  flake.modules.nixos.web =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.web;
      inherit (lib)
        concatLists
        concatStringsSep
        intersectLists
        mapAttrs'
        mapAttrsToList
        mergeAttrsList
        mkIf
        mkOption
        nameValuePair
        optional
        optionalAttrs
        types
        unique
        ;

      enabled = cfg.sites != { } || cfg.services != { };
      validName = name: builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null;

      headers = ''
        header {
          Strict-Transport-Security "max-age=31536000"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';

      hardening = {
        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged @resources"
        ];
        SystemCallErrno = "EPERM";
      };

      hostOptions = {
        domain = mkOption { type = types.str; };
        aliases = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        extraConfig = mkOption {
          type = types.lines;
          default = "";
        };
      };

      redirectHosts =
        app:
        optionalAttrs (app.aliases != [ ]) {
          ${concatStringsSep ", " app.aliases}.extraConfig = ''
            ${headers}
            redir https://${app.domain}{uri} permanent
          '';
        };

      siteHosts =
        _name: site:
        {
          ${site.domain}.extraConfig = ''
            encode zstd gzip
            ${headers}
            ${site.extraConfig}
            root * ${site.package}
            file_server
          '';
        }
        // redirectHosts site;

      serviceHosts =
        _name: service:
        {
          ${service.domain}.extraConfig = ''
            encode zstd gzip
            ${headers}
            ${service.extraConfig}
            reverse_proxy 127.0.0.1:${toString service.port}
          '';
        }
        // redirectHosts service;

      virtualHosts = mergeAttrsList (
        (mapAttrsToList siteHosts cfg.sites) ++ (mapAttrsToList serviceHosts cfg.services)
      );

      hostDomains = concatLists (
        (mapAttrsToList (_: s: [
          s.domain
        ] ++ s.aliases) cfg.sites)
        ++ (mapAttrsToList (_: s: [
          s.domain
        ] ++ s.aliases) cfg.services)
      );
      servicePorts = mapAttrsToList (_: s: s.port) cfg.services;

      nameAssertion = kind: name: {
        assertion = validName name;
        message = "web.${kind}.${name} must use lowercase kebab-case.";
      };
    in
    {
      options.web = {
        user = mkOption {
          type = types.str;
          default = "web";
        };
        group = mkOption {
          type = types.str;
          default = "web";
        };
        email = mkOption {
          type = types.str;
          default = config.profile.email;
        };
        sites = mkOption {
          type = types.attrsOf (types.submodule {
            options = hostOptions // {
              package = mkOption {
                type = types.package;
                description = "Derivation whose store path is the static site root.";
              };
            };
          });
          default = { };
        };
        services = mkOption {
          type = types.attrsOf (types.submodule {
            options = hostOptions // {
              package = mkOption {
                type = types.package;
                description = "Derivation providing bin/web-<name>.";
              };
              port = mkOption { type = types.port; };
              envFile = mkOption {
                type = types.nullOr types.path;
                default = null;
              };
            };
          });
          default = { };
        };
      };

      config = mkIf enabled {
        assertions =
          (mapAttrsToList (name: _: nameAssertion "sites" name) cfg.sites)
          ++ (mapAttrsToList (name: _: nameAssertion "services" name) cfg.services)
          ++ [
            {
              assertion = intersectLists (builtins.attrNames cfg.sites) (
                builtins.attrNames cfg.services
              ) == [ ];
              message = "web app names must be unique across sites and services.";
            }
            {
              assertion = builtins.length hostDomains == builtins.length (unique hostDomains);
              message = "web domains must be unique.";
            }
            {
              assertion = builtins.length servicePorts == builtins.length (unique servicePorts);
              message = "web service ports must be unique.";
            }
          ];

        users.groups.${cfg.group} = { };
        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
          home = "/var/lib/web";
        };

        networking.firewall = {
          allowedTCPPorts = [
            80
            443
          ];
          allowedUDPPorts = [ 443 ];
        };

        services.caddy = {
          enable = true;
          email = cfg.email;
          inherit virtualHosts;
        };

        systemd.services = mapAttrs' (
          name: service:
          nameValuePair "web-${name}" {
            description = "web service ${name}";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            environment = {
              NODE_ENV = "production";
              HOST = "127.0.0.1";
              PORT = toString service.port;
              HOME = "/var/lib/web/${name}";
            };
            serviceConfig = hardening // {
              Type = "exec";
              User = cfg.user;
              Group = cfg.group;
              WorkingDirectory = service.package;
              StateDirectory = "web/${name}";
              EnvironmentFile = optional (service.envFile != null) service.envFile;
              Restart = "on-failure";
              RestartSec = "5s";
              ExecStart = "${service.package}/bin/web-${name}";
            };
          }
        ) cfg.services;
      };
    };
}
