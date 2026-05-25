{ ... }:
{
  flake.modules.nixos.servarr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.media.servarr;
      inherit (lib)
        mapAttrs
        mapAttrsToList
        mkDefault
        mkForce
        mkIf
        mkMerge
        mkOption
        optionalAttrs
        types
        ;

      authenticationRequired = "DisabledForLocalAddresses";
      sqlite = lib.getExe' pkgs.sqlite "sqlite3";
      xml = lib.getExe pkgs.xmlstarlet;

      apps = {
        sonarr = {
          inherit (config.services.sonarr) dataDir enable;
          database = "sonarr.db";
        };
        radarr = {
          inherit (config.services.radarr) dataDir enable;
          database = "radarr.db";
        };
        prowlarr = {
          inherit (config.services.prowlarr) dataDir enable;
          database = "prowlarr.db";
        };
      };

      setupScript =
        name: app:
        pkgs.writeShellScript "${name}-initial-auth" ''
          set -euo pipefail

          data_dir=${lib.escapeShellArg app.dataDir}
          database=$data_dir/${lib.escapeShellArg app.database}
          config=$data_dir/config.xml
          username=${lib.escapeShellArg cfg.admin.name}
          password=$(tr -d '\r\n' < "$CREDENTIALS_DIRECTORY/admin-password")

          if [ -z "$password" ]; then
            printf '%s admin password is empty\n' ${lib.escapeShellArg name} >&2
            exit 1
          fi

          mkdir -p "$data_dir"

          has_user=0
          if [ -s "$database" ]; then
            has_user=$(${sqlite} "$database" "select case when exists(select 1 from sqlite_master where type = 'table' and name = 'Users') and exists(select 1 from Users limit 1) then 1 else 0 end" 2>/dev/null || printf 0)
          fi

          if [ "$has_user" = 1 ]; then
            ${xml} ed -L -d /Config/Username -d /Config/Password "$config" >/dev/null 2>&1 || true
            exit 0
          fi

          if [ ! -s "$config" ]; then
            printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>' '<Config />' > "$config"
          fi

          set_xml() {
            key=$1
            value=$2
            if [ "$(${xml} sel -t -v "count(/Config/$key)" "$config")" = 0 ]; then
              ${xml} ed -L -s /Config -t elem -n "$key" -v "$value" "$config"
            else
              ${xml} ed -L -u "/Config/$key" -v "$value" "$config"
            fi
          }

          set_xml AuthenticationMethod Forms
          set_xml AuthenticationRequired ${lib.escapeShellArg authenticationRequired}
          set_xml LaunchBrowser False
          set_xml AnalyticsEnabled False
          set_xml UpdateMechanism External
          set_xml UpdateAutomatically False
          set_xml Username "$username"
          set_xml Password "$password"
        '';

      cleanupScript =
        name: app:
        pkgs.writeShellScript "${name}-cleanup-initial-auth" ''
          set -euo pipefail

          data_dir=${lib.escapeShellArg app.dataDir}
          database=$data_dir/${lib.escapeShellArg app.database}
          config=$data_dir/config.xml

          for _ in $(seq 1 60); do
            if [ -s "$database" ] && [ "$(${sqlite} "$database" "select case when exists(select 1 from sqlite_master where type = 'table' and name = 'Users') and exists(select 1 from Users limit 1) then 1 else 0 end" 2>/dev/null || printf 0)" = 1 ]; then
              ${xml} ed -L -d /Config/Username -d /Config/Password "$config" >/dev/null 2>&1 || true
              exit 0
            fi
            sleep 1
          done

          exit 0
        '';
    in
    {
      options.media.servarr = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        group = mkOption {
          type = types.str;
          default = "media";
        };
        admin = {
          name = mkOption {
            type = types.str;
            default = config.profile.username;
          };
          passwordFile = mkOption { type = types.str; };
        };
      };

      config = mkIf cfg.enable {
        services = mkMerge (
          [
            {
              sonarr.group = mkDefault cfg.group;
              radarr.group = mkDefault cfg.group;
            }
          ]
          ++ mapAttrsToList (
            name: app:
            mkIf app.enable {
              ${name}.settings = {
                app.launchBrowser = mkDefault false;
                auth = {
                  method = mkDefault "Forms";
                  required = mkDefault authenticationRequired;
                };
                log.analyticsEnabled = mkDefault false;
                server.bindaddress = mkDefault "127.0.0.1";
                update = {
                  automatically = mkDefault false;
                  mechanism = mkDefault "external";
                };
              };
            }
          ) apps
        );

        users.groups.${cfg.group} = { };
        users.users.${config.profile.username}.extraGroups = [ cfg.group ];

        systemd.services = mapAttrs (
          name: app:
          mkIf app.enable {
            wants = [ "sops-install-secrets.service" ];
            after = [ "sops-install-secrets.service" ];
            path = [ pkgs.coreutils ];
            preStart = "${setupScript name app}";
            postStart = "${cleanupScript name app}";
            serviceConfig = {
              LoadCredential = [ "admin-password:${cfg.admin.passwordFile}" ];
            }
            // optionalAttrs (name == "sonarr" || name == "radarr") {
              UMask = mkForce "0002";
            }
            // optionalAttrs (name == "prowlarr") {
              UMask = mkDefault "0077";
            };
          }
        ) apps;
      };
    };
}
