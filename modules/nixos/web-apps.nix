{ ... }:
{
  flake.modules.nixos.webApps =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.webApps;
      inherit (lib)
        concatStringsSep
        filterAttrs
        mapAttrs'
        mapAttrsToList
        mkIf
        mkOption
        nameValuePair
        optional
        optionalAttrs
        optionalString
        types
        ;

      enabled = cfg.repos != { } || cfg.sites != { } || cfg.services != { };
      serving = cfg.sites != { } || cfg.services != { };

      safeName = lib.replaceStrings [ "." "/" ":" "@" " " ] [ "-" "-" "-" "-" "-" ];
      appState = name: "webapps/apps/${safeName name}";
      appRoot = name: "/var/lib/${appState name}";
      appCache = name: "/var/cache/${appState name}";
      repoState = name: "webapps/repos/${safeName name}";
      repoRoot = name: "/var/lib/${repoState name}";
      checkout = name: "${repoRoot name}/checkout";
      siteRoot = name: "${appRoot name}/site";
      repoUnit = name: "web-repo-${safeName name}";
      siteUnit = name: "web-site-${safeName name}";
      serviceUnit = name: "web-service-${safeName name}";
      caddySite = domains: concatStringsSep ", " domains;
      ssh = lib.getExe' pkgs.openssh "ssh";

      repoOf = app: if builtins.hasAttr app.repo cfg.repos then cfg.repos.${app.repo} else null;
      repoKeyFiles =
        app:
        let
          repo = repoOf app;
        in
        optional (repo != null && repo.keyFile != null) repo.keyFile;
      repoCredentials =
        app:
        let
          repo = repoOf app;
        in
        optionalAttrs (repo != null && repo.keyFile != null) {
          LoadCredential = [ "git-key:${repo.keyFile}" ];
        };
      repoGitSsh =
        app:
        let
          repo = repoOf app;
        in
        optionalString (repo != null && repo.keyFile != null) ''
          export GIT_SSH_COMMAND="${ssh} -i $CREDENTIALS_DIRECTORY/git-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/ssh_known_hosts"
        '';
      conditions = app: app.envFiles ++ app.requiredFiles ++ repoKeyFiles app;
      repoDeps = app: optional (repoOf app != null) "${repoUnit app.repo}.service";
      cloneArgs =
        repo: optionalString repo.shallow "--depth=1 --filter=blob:none --no-tags --single-branch";
      fetchArgs = repo: optionalString repo.shallow "--depth=1 --filter=blob:none --no-tags";

      hardening = {
        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };

      repoType = types.submodule {
        options = {
          url = mkOption { type = types.str; };
          branch = mkOption {
            type = types.str;
            default = "main";
          };
          keyFile = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          shallow = mkOption {
            type = types.bool;
            default = true;
          };
        };
      };

      appOptions = name: {
        domains = mkOption {
          type = types.nonEmptyListOf types.str;
          default = [ name ];
        };
        repo = mkOption { type = types.str; };
        install = mkOption {
          type = types.str;
          default = "${lib.getExe pkgs.bun} install --frozen-lockfile";
        };
        env = mkOption {
          type = types.attrsOf types.str;
          default = { };
        };
        envFiles = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        requiredFiles = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        extraConfig = mkOption {
          type = types.lines;
          default = "";
        };
      };

      siteType = types.submodule (
        { name, ... }:
        {
          options = (appOptions name) // {
            output = mkOption {
              type = types.str;
              default = "_site";
            };
            build = mkOption {
              type = types.str;
              default = "${lib.getExe pkgs.bun} run build";
            };
            timer = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
          };
        }
      );

      serviceType = types.submodule (
        { name, ... }:
        {
          options = (appOptions name) // {
            port = mkOption { type = types.port; };
            build = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            start = mkOption {
              type = types.str;
              default = "${lib.getExe pkgs.bun} run start";
            };
          };
        }
      );

      repoAssertion = kind: name: app: {
        assertion = builtins.hasAttr app.repo cfg.repos;
        message = "webApps.${kind}.${name}.repo references an unknown repo.";
      };

      repoService = name: repo: {
        description = "Sync web repo ${name}";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = with pkgs; [
          coreutils
          git
          openssh
        ];
        environment = {
          HOME = repoRoot name;
          GIT_TERMINAL_PROMPT = "0";
        };
        unitConfig = optionalAttrs (repo.keyFile != null) {
          ConditionPathExists = repo.keyFile;
        };
        serviceConfig =
          hardening
          // optionalAttrs (repo.keyFile != null) {
            LoadCredential = [ "git-key:${repo.keyFile}" ];
          }
          // {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            StateDirectory = repoState name;
            StateDirectoryMode = "0750";
            CacheDirectory = repoState name;
            CacheDirectoryMode = "0750";
            ReadWritePaths = [ (repoRoot name) ];
            UMask = "0027";
            ExecStart = pkgs.writeShellScript "sync-${safeName name}" ''
              set -euo pipefail

              ${optionalString (repo.keyFile != null) ''
                export GIT_SSH_COMMAND="${ssh} -i $CREDENTIALS_DIRECTORY/git-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/ssh_known_hosts"
              ''}
              ${optionalString (repo.keyFile == null) ''
                export GIT_SSH_COMMAND="${ssh} -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/ssh_known_hosts"
              ''}

              checkout=${lib.escapeShellArg (checkout name)}
              branch=${lib.escapeShellArg repo.branch}
              url=${lib.escapeShellArg repo.url}

              if [ ! -d "$checkout/.git" ]; then
                rm -rf "$checkout"
                git clone ${cloneArgs repo} --branch "$branch" "$url" "$checkout"
              else
                git -C "$checkout" remote set-url origin "$url"
                git -C "$checkout" fetch ${fetchArgs repo} --prune --force origin "+refs/heads/$branch:refs/remotes/origin/$branch"
                git -C "$checkout" checkout -B "$branch" "refs/remotes/origin/$branch"
                git -C "$checkout" reset --hard "refs/remotes/origin/$branch"
                git -C "$checkout" clean -ffdx
              fi

              git -C "$checkout" rev-parse HEAD > "$STATE_DIRECTORY/revision"
            '';
          };
      };

      siteService =
        name: site:
        let
          deps = repoDeps site;
          required = conditions site;
        in
        {
          description = "Build web site ${name}";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ] ++ deps;
          requires = deps;
          after = [ "network-online.target" ] ++ deps;
          path = with pkgs; [
            bun
            coreutils
            findutils
            git
            openssh
          ];
          environment = {
            NODE_ENV = "production";
          }
          // site.env;
          unitConfig = optionalAttrs (required != [ ]) {
            ConditionPathExists = required;
          };
          serviceConfig =
            hardening
            // repoCredentials site
            // optionalAttrs (site.envFiles != [ ]) {
              EnvironmentFile = site.envFiles;
            }
            // {
              Type = "oneshot";
              User = cfg.user;
              Group = cfg.group;
              WorkingDirectory = checkout site.repo;
              StateDirectory = appState name;
              StateDirectoryMode = "0755";
              CacheDirectory = appState name;
              CacheDirectoryMode = "0750";
              ReadWritePaths = [
                (checkout site.repo)
                (appRoot name)
                (appCache name)
              ];
              UMask = "0022";
              ExecStart = pkgs.writeShellScript "build-${safeName name}" ''
                set -euo pipefail

                export HOME="$STATE_DIRECTORY"
                export XDG_CACHE_HOME="$CACHE_DIRECTORY"
                export BUN_INSTALL_CACHE_DIR="$CACHE_DIRECTORY/bun"
                ${repoGitSsh site}

                cd ${lib.escapeShellArg (checkout site.repo)}
                ${site.install}
                ${site.build}

                output=${lib.escapeShellArg site.output}
                target="$STATE_DIRECTORY/site"
                tmp=$(mktemp -d "$STATE_DIRECTORY/.site.XXXXXX")
                trap 'rm -rf "$tmp"' EXIT

                cp -R "$output/." "$tmp/"
                find "$tmp" -type d -exec chmod 0755 {} +
                find "$tmp" -type f -exec chmod 0644 {} +

                rm -rf "''${target}.old"
                if [ -e "$target" ]; then
                  mv "$target" "''${target}.old"
                fi
                if mv "$tmp" "$target"; then
                  trap - EXIT
                  rm -rf "''${target}.old"
                else
                  if [ -e "''${target}.old" ]; then
                    mv "''${target}.old" "$target"
                  fi
                  exit 1
                fi
              '';
            };
        };

      runtimeService =
        name: service:
        let
          deps = repoDeps service;
          required = conditions service;
        in
        {
          description = "Run web service ${name}";
          wantedBy = [ "multi-user.target" ];
          requires = deps;
          after = [ "network.target" ] ++ deps;
          path = with pkgs; [
            bun
            coreutils
            git
            openssh
          ];
          environment = {
            NODE_ENV = "production";
            HOST = "127.0.0.1";
            PORT = toString service.port;
          }
          // service.env;
          unitConfig = optionalAttrs (required != [ ]) {
            ConditionPathExists = required;
          };
          serviceConfig =
            hardening
            // repoCredentials service
            // optionalAttrs (service.envFiles != [ ]) {
              EnvironmentFile = service.envFiles;
            }
            // {
              User = cfg.user;
              Group = cfg.group;
              WorkingDirectory = checkout service.repo;
              StateDirectory = appState name;
              StateDirectoryMode = "0750";
              CacheDirectory = appState name;
              CacheDirectoryMode = "0750";
              ReadWritePaths = [
                (checkout service.repo)
                (appRoot name)
                (appCache name)
              ];
              Restart = "on-failure";
              RestartSec = "5s";
              UMask = "0027";
              ExecStart = pkgs.writeShellScript "run-${safeName name}" ''
                set -euo pipefail

                export HOME="$STATE_DIRECTORY"
                export XDG_CACHE_HOME="$CACHE_DIRECTORY"
                export BUN_INSTALL_CACHE_DIR="$CACHE_DIRECTORY/bun"
                ${repoGitSsh service}

                cd ${lib.escapeShellArg (checkout service.repo)}
                ${service.install}
                ${optionalString (service.build != null) service.build}
                exec ${service.start}
              '';
            };
        };

      headers = ''
        header {
          Strict-Transport-Security "max-age=31536000"
          X-Content-Type-Options "nosniff"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';

      siteHost =
        name: site:
        nameValuePair (caddySite site.domains) {
          extraConfig = ''
            encode zstd gzip
            ${headers}
            root * ${siteRoot name}
            file_server
            ${site.extraConfig}
          '';
        };

      serviceHost =
        _name: service:
        nameValuePair (caddySite service.domains) {
          extraConfig = ''
            encode zstd gzip
            ${headers}
            reverse_proxy 127.0.0.1:${toString service.port}
            ${service.extraConfig}
          '';
        };

      timedSites = filterAttrs (_name: site: site.timer != null) cfg.sites;
      siteUnits = mapAttrsToList (name: _site: "${siteUnit name}.service") cfg.sites;
    in
    {
      options.webApps = {
        user = mkOption {
          type = types.str;
          default = "webapp";
        };
        group = mkOption {
          type = types.str;
          default = "webapp";
        };
        email = mkOption {
          type = types.str;
          default = config.profile.email;
        };
        repos = mkOption {
          type = types.attrsOf repoType;
          default = { };
        };
        sites = mkOption {
          type = types.attrsOf siteType;
          default = { };
        };
        services = mkOption {
          type = types.attrsOf serviceType;
          default = { };
        };
      };

      config = mkIf enabled {
        assertions =
          (mapAttrsToList (repoAssertion "sites") cfg.sites)
          ++ (mapAttrsToList (repoAssertion "services") cfg.services);

        users.groups.${cfg.group} = { };
        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
          home = "/var/lib/webapps";
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/webapps 0755 root root -"
          "d /var/lib/webapps/keys 0700 root root -"
          "d /var/lib/webapps/secrets 0700 root root -"
        ];

        programs.ssh.knownHosts."github.com".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

        environment.systemPackages = [ pkgs.bun ];

        networking.firewall = mkIf serving {
          allowedTCPPorts = [
            80
            443
          ];
          allowedUDPPorts = [ 443 ];
        };

        services.caddy = mkIf serving {
          enable = true;
          email = cfg.email;
          virtualHosts = (mapAttrs' siteHost cfg.sites) // (mapAttrs' serviceHost cfg.services);
        };

        systemd.services =
          (mapAttrs' (name: repo: nameValuePair (repoUnit name) (repoService name repo)) cfg.repos)
          // (mapAttrs' (name: site: nameValuePair (siteUnit name) (siteService name site)) cfg.sites)
          // (mapAttrs' (
            name: service: nameValuePair (serviceUnit name) (runtimeService name service)
          ) cfg.services)
          // optionalAttrs serving {
            caddy = {
              wants = siteUnits;
              after = siteUnits;
            };
          };

        systemd.timers = mapAttrs' (
          name: site:
          nameValuePair (siteUnit name) {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = site.timer;
              Persistent = true;
              RandomizedDelaySec = "5min";
              Unit = "${siteUnit name}.service";
            };
          }
        ) timedSites;
      };
    };
}
