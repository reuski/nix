{ ... }:
{
  flake.modules.nixos.web =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.web;
      inherit (lib)
        concatLists
        concatStringsSep
        hasPrefix
        intersectLists
        mapAttrs'
        mapAttrsToList
        mergeAttrsList
        mkIf
        mkOption
        nameValuePair
        optional
        optionalAttrs
        optionalString
        types
        unique
        ;

      stateDir = "/var/lib/web";
      enabled = cfg.sites != { } || cfg.services != { };
      bun = lib.getExe pkgs.bun;
      ssh = lib.getExe' pkgs.openssh "ssh";

      safeName = lib.replaceStrings [ "." "/" ":" "@" " " "_" ] [ "-" "-" "-" "-" "-" "-" ];
      validName = name: builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null;
      appState = name: "web/apps/${safeName name}";
      appRoot = name: "/var/lib/${appState name}";
      appCache = name: "/var/cache/${appState name}";
      checkout = name: "${appRoot name}/src";
      siteRoot = name: "${appRoot name}/site";
      syncUnit = name: "web-sync-${safeName name}";
      siteUnit = name: "web-site-${safeName name}";
      serviceUnit = name: "web-service-${safeName name}";
      caddyHosts = domains: concatStringsSep ", " domains;
      appDomains = app: [ app.domain ] ++ app.aliases;

      bunInstall = ''
        if [ -e bun.lock ] || [ -e bun.lockb ]; then
          ${bun} install --frozen-lockfile
        else
          ${bun} install
        fi
      '';

      sshRepo = repo: hasPrefix "git@" repo.url || hasPrefix "ssh://" repo.url;
      httpsRepo = repo: hasPrefix "https://" repo.url;
      cloneArgs =
        repo: optionalString repo.shallow "--depth=1 --filter=blob:none --no-tags --single-branch";
      fetchArgs = repo: optionalString repo.shallow "--depth=1 --filter=blob:none --no-tags";

      repoKeyFiles = app: optional (app.repo.keyFile != null) app.repo.keyFile;
      repoCredentials = app: optional (app.repo.keyFile != null) "git-key:${app.repo.keyFile}";
      appCredentials = app: optional (app.envFile != null) "env:${app.envFile}" ++ repoCredentials app;
      loadCredentials = credentials: optionalAttrs (credentials != [ ]) { LoadCredential = credentials; };
      conditions = app: unique (optional (app.envFile != null) app.envFile ++ repoKeyFiles app);
      repoGitSsh =
        app:
        optionalString (app.repo.keyFile != null) ''
          export GIT_SSH_COMMAND="${ssh} -i $CREDENTIALS_DIRECTORY/git-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/ssh_known_hosts"
        '';
      envSetup =
        app:
        optionalString (app.envFile != null) ''
          rm -f .env
          ln -s "$CREDENTIALS_DIRECTORY/env" .env
        '';
      envCleanup = app: optionalString (app.envFile != null) "rm -f .env";
      usesSsh = builtins.any (app: sshRepo app.repo || app.repo.keyFile != null) (
        builtins.attrValues cfg.sites ++ builtins.attrValues cfg.services
      );

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

      repoOption = types.coercedTo types.str (url: { inherit url; }) repoType;

      appOptions = {
        domain = mkOption { type = types.str; };
        aliases = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        repo = mkOption { type = repoOption; };
        install = mkOption {
          type = types.lines;
          default = bunInstall;
        };
        envFile = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
      };

      siteType = types.submodule {
        options = appOptions // {
          output = mkOption {
            type = types.str;
            default = "_site";
          };
          build = mkOption {
            type = types.lines;
            default = "${bun} run build";
          };
        };
      };

      serviceType = types.submodule {
        options = appOptions // {
          port = mkOption { type = types.port; };
          build = mkOption {
            type = types.nullOr types.lines;
            default = "${bun} run build";
          };
          start = mkOption {
            type = types.str;
            default = "${bun} run start";
          };
        };
      };

      nameAssertion = kind: name: _value: {
        assertion = validName name;
        message = "web.${kind}.${name} must use lowercase kebab-case.";
      };

      repoUrlAssertion = kind: name: app: {
        assertion = httpsRepo app.repo || sshRepo app.repo;
        message = "web.${kind}.${name}.repo.url must use HTTPS or SSH.";
      };

      repoKeyAssertion = kind: name: app: {
        assertion = !(sshRepo app.repo) || app.repo.keyFile != null;
        message = "web.${kind}.${name}.repo.keyFile is required for SSH repository URLs.";
      };

      domainAssertion = kind: name: app: {
        assertion = app.domain != "" && builtins.all (domain: domain != "") app.aliases;
        message = "web.${kind}.${name} domains must not be empty.";
      };

      siteNames = builtins.attrNames cfg.sites;
      serviceNames = builtins.attrNames cfg.services;
      overlappingApps = intersectLists siteNames serviceNames;
      hostDomains =
        concatLists (mapAttrsToList (_name: site: appDomains site) cfg.sites)
        ++ concatLists (mapAttrsToList (_name: service: appDomains service) cfg.services);
      servicePorts = mapAttrsToList (_name: service: service.port) cfg.services;

      syncService = mode: name: app: {
        description = "Sync web app ${name}";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = with pkgs; [
          coreutils
          git
          openssh
        ];
        environment = {
          HOME = appRoot name;
          GIT_TERMINAL_PROMPT = "0";
        };
        unitConfig = optionalAttrs (repoKeyFiles app != [ ]) {
          ConditionPathExists = repoKeyFiles app;
        };
        serviceConfig =
          hardening
          // loadCredentials (repoCredentials app)
          // {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            StateDirectory = appState name;
            StateDirectoryMode = mode;
            CacheDirectory = appState name;
            CacheDirectoryMode = "0750";
            ReadWritePaths = [ (appRoot name) ];
            TimeoutStartSec = "10min";
            UMask = "0027";
            ExecStart = pkgs.writeShellScript "sync-${safeName name}" ''
              set -euo pipefail

              ${repoGitSsh app}

              checkout=${lib.escapeShellArg (checkout name)}
              branch=${lib.escapeShellArg app.repo.branch}
              url=${lib.escapeShellArg app.repo.url}

              if [ ! -d "$checkout/.git" ]; then
                rm -rf "$checkout"
                git clone ${cloneArgs app.repo} --branch "$branch" "$url" "$checkout"
              else
                git -C "$checkout" remote set-url origin "$url"
                git -C "$checkout" fetch ${fetchArgs app.repo} --prune --force origin "+refs/heads/$branch:refs/remotes/origin/$branch"
                git -C "$checkout" checkout -B "$branch" "refs/remotes/origin/$branch"
                git -C "$checkout" reset --hard "refs/remotes/origin/$branch"
                git -C "$checkout" clean -ffdx
              fi

              git -C "$checkout" rev-parse HEAD > "$STATE_DIRECTORY/revision"
            '';
          };
      };

      siteService = name: site: {
        description = "Build web site ${name}";
        wantedBy = [ "multi-user.target" ];
        wants = [ "${syncUnit name}.service" ];
        requires = [ "${syncUnit name}.service" ];
        after = [ "${syncUnit name}.service" ];
        path = with pkgs; [
          bun
          coreutils
          findutils
          git
          openssh
        ];
        environment.NODE_ENV = "production";
        unitConfig = optionalAttrs (conditions site != [ ]) {
          ConditionPathExists = conditions site;
        };
        serviceConfig =
          hardening
          // loadCredentials (appCredentials site)
          // {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = checkout name;
            StateDirectory = appState name;
            StateDirectoryMode = "0755";
            CacheDirectory = appState name;
            CacheDirectoryMode = "0750";
            ReadWritePaths = [
              (appRoot name)
              (appCache name)
            ];
            TimeoutStartSec = "15min";
            UMask = "0022";
            ExecStart = pkgs.writeShellScript "build-${safeName name}" ''
              set -euo pipefail

              tmp=""
              cleanup() {
                ${envCleanup site}
                if [ -n "$tmp" ]; then
                  rm -rf "$tmp"
                fi
              }
              trap cleanup EXIT

              export HOME="$STATE_DIRECTORY"
              export XDG_CACHE_HOME="$CACHE_DIRECTORY"
              export BUN_INSTALL_CACHE_DIR="$CACHE_DIRECTORY/bun"
              ${repoGitSsh site}

              cd ${lib.escapeShellArg (checkout name)}
              ${envSetup site}
              ${site.install}
              ${site.build}

              output=${lib.escapeShellArg site.output}
              target="$STATE_DIRECTORY/site"
              tmp=$(mktemp -d "$STATE_DIRECTORY/.site.XXXXXX")

              cp -R "$output/." "$tmp/"
              find "$tmp" -type d -exec chmod 0755 {} +
              find "$tmp" -type f -exec chmod 0644 {} +

              rm -rf "''${target}.old"
              if [ -e "$target" ]; then
                mv "$target" "''${target}.old"
              fi
              if mv "$tmp" "$target"; then
                tmp=""
                trap - EXIT
                cleanup
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

      runtimeService = name: service: {
        description = "Run web service ${name}";
        wantedBy = [ "multi-user.target" ];
        wants = [ "${syncUnit name}.service" ];
        requires = [ "${syncUnit name}.service" ];
        after = [ "${syncUnit name}.service" ];
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
        };
        unitConfig = optionalAttrs (conditions service != [ ]) {
          ConditionPathExists = conditions service;
        };
        serviceConfig =
          hardening
          // loadCredentials (appCredentials service)
          // optionalAttrs (service.envFile != null) {
            ExecStopPost = pkgs.writeShellScript "clean-${safeName name}-env" ''
              rm -f ${lib.escapeShellArg (checkout name)}/.env
            '';
          }
          // {
            Type = "exec";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = checkout name;
            StateDirectory = appState name;
            StateDirectoryMode = "0750";
            CacheDirectory = appState name;
            CacheDirectoryMode = "0750";
            ReadWritePaths = [
              (appRoot name)
              (appCache name)
            ];
            Restart = "on-failure";
            RestartSec = "5s";
            RestartSteps = 5;
            RestartMaxDelaySec = "1min";
            UMask = "0027";
            ExecStart = pkgs.writeShellScript "run-${safeName name}" ''
              set -euo pipefail

              export HOME="$STATE_DIRECTORY"
              export XDG_CACHE_HOME="$CACHE_DIRECTORY"
              export BUN_INSTALL_CACHE_DIR="$CACHE_DIRECTORY/bun"
              ${repoGitSsh service}

              cd ${lib.escapeShellArg (checkout name)}
              ${envSetup service}
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

      redirectHosts =
        app:
        optionalAttrs (app.aliases != [ ]) {
          ${caddyHosts app.aliases}.extraConfig = ''
            ${headers}
            redir https://${app.domain}{uri} permanent
          '';
        };

      siteHosts =
        name: site:
        {
          ${site.domain}.extraConfig = ''
            encode zstd gzip
            ${headers}
            root * ${siteRoot name}
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
            reverse_proxy 127.0.0.1:${toString service.port}
          '';
        }
        // redirectHosts service;

      virtualHosts = mergeAttrsList (
        (mapAttrsToList siteHosts cfg.sites) ++ (mapAttrsToList serviceHosts cfg.services)
      );
      siteUnits = mapAttrsToList (name: _site: "${siteUnit name}.service") cfg.sites;
      serviceUnits = mapAttrsToList (name: _service: "${serviceUnit name}.service") cfg.services;
      hostedUnits = siteUnits ++ serviceUnits;
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
          (mapAttrsToList (nameAssertion "sites") cfg.sites)
          ++ (mapAttrsToList (nameAssertion "services") cfg.services)
          ++ (mapAttrsToList (repoUrlAssertion "sites") cfg.sites)
          ++ (mapAttrsToList (repoUrlAssertion "services") cfg.services)
          ++ (mapAttrsToList (repoKeyAssertion "sites") cfg.sites)
          ++ (mapAttrsToList (repoKeyAssertion "services") cfg.services)
          ++ (mapAttrsToList (domainAssertion "sites") cfg.sites)
          ++ (mapAttrsToList (domainAssertion "services") cfg.services)
          ++ [
            {
              assertion = overlappingApps == [ ];
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
          home = stateDir;
        };

        systemd.tmpfiles.rules = [
          "d ${stateDir} 0755 root root -"
          "d ${stateDir}/apps 0755 root root -"
          "d ${stateDir}/keys 0700 root root -"
          "d ${stateDir}/secrets 0700 root root -"
        ];

        programs.ssh.knownHosts = optionalAttrs usesSsh {
          "github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
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
          virtualHosts = virtualHosts;
        };

        systemd.services =
          (mapAttrs' (name: site: nameValuePair (syncUnit name) (syncService "0755" name site)) cfg.sites)
          // (mapAttrs' (
            name: service: nameValuePair (syncUnit name) (syncService "0750" name service)
          ) cfg.services)
          // (mapAttrs' (name: site: nameValuePair (siteUnit name) (siteService name site)) cfg.sites)
          // (mapAttrs' (
            name: service: nameValuePair (serviceUnit name) (runtimeService name service)
          ) cfg.services)
          // {
            caddy = {
              wants = hostedUnits;
              after = siteUnits;
            };
          };

      };
    };
}
