{ ... }:
{
  flake.modules.nixos.trek =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.trek;
      containerPort = 3000;
      stateDir = "/var/lib/trek";
      # TREK runs its app as the image's `node` user (uid 1000) and its
      # entrypoint chowns the data/uploads volumes to node:node. tmpfiles must
      # own them the same way, otherwise activation resets them to root and the
      # running app loses write access (file uploads fail with EACCES).
      nodeUid = 1000;
      nodeGid = 1000;
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
    in
    {
      options.trek = {
        enable = mkEnableOption "TREK";
        port = mkOption {
          type = types.port;
          default = 3002;
          description = "Loopback backend port.";
        };
        url = mkOption {
          type = types.str;
          description = "Canonical HTTPS URL used for cookies and generated links.";
        };
        allowedOrigins = mkOption {
          type = types.listOf types.str;
          default = [ cfg.url ];
          description = "HTTPS origins allowed to access TREK.";
        };
        environmentFile = mkOption {
          type = types.path;
          description = "SOPS-provided environment file containing ENCRYPTION_KEY.";
        };
      };

      config = mkIf cfg.enable {
        quadlets.trek = {
          image = "docker.io/mauriceboe/trek:latest";
          port = cfg.port;
          containerConfig = {
            networks = [ ];
            publishPorts = [ "127.0.0.1:${toString cfg.port}:${toString containerPort}" ];
            readOnly = true;
            noNewPrivileges = true;
            dropCapabilities = [ "ALL" ];
            addCapabilities = [
              "CHOWN"
              "SETUID"
              "SETGID"
            ];
            tmpfses = [ "/tmp:noexec,nosuid,size=128m" ];
            healthCmd = "wget -qO- http://127.0.0.1:${toString containerPort}/api/health || exit 1";
            healthInterval = "30s";
            healthTimeout = "5s";
            healthRetries = 3;
            healthStartPeriod = "15s";
          };
          environment = {
            NODE_ENV = "production";
            PORT = toString containerPort;
            APP_URL = cfg.url;
            ALLOWED_ORIGINS = lib.concatStringsSep "," cfg.allowedOrigins;
            FORCE_HTTPS = "true";
            TRUST_PROXY = "1";
          };
          environmentFiles = [ cfg.environmentFile ];
          stateDir = {
            path = "${stateDir}/data";
            mount = "/app/data";
            owner = toString nodeUid;
            group = toString nodeGid;
          };
          volumes = [ "${stateDir}/uploads:/app/uploads" ];
        };

        media.directories."${stateDir}/uploads" = {
          mode = "0750";
          owner = toString nodeUid;
          group = toString nodeGid;
        };
      };
    };
}
