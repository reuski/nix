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

      prowlarrConfigure = pkgs.writeShellScript "prowlarr-configure" ''
        set -euo pipefail

        prowlarr_url=http://127.0.0.1:${toString config.services.prowlarr.settings.server.port}
        config=${lib.escapeShellArg "${config.services.prowlarr.dataDir}/config.xml"}
        indexers=$CREDENTIALS_DIRECTORY/indexers

        request() {
          method=$1
          path=$2
          ${lib.getExe pkgs.curl} --fail --silent --show-error \
            --request "$method" \
            --header "X-Api-Key: $api_key" \
            --header 'Content-Type: application/json' \
            "$prowlarr_url/api/v1/$path"
        }

        send() {
          method=$1
          path=$2
          ${lib.getExe pkgs.curl} --fail --silent --show-error \
            --request "$method" \
            --header "X-Api-Key: $api_key" \
            --header 'Content-Type: application/json' \
            --data @- \
            "$prowlarr_url/api/v1/$path" >/dev/null
        }

        tag_id() {
          label=$1
          id=$(request GET tag | ${lib.getExe pkgs.jq} -r \
            --arg label "$label" \
            'map(select(.label == $label)) | first | .id // empty')
          if [ -z "$id" ]; then
            id=$(${lib.getExe pkgs.jq} -n --arg label "$label" '{ label: $label }' | ${lib.getExe pkgs.curl} --fail --silent --show-error \
              --request POST \
              --header "X-Api-Key: $api_key" \
              --header 'Content-Type: application/json' \
              --data @- \
              "$prowlarr_url/api/v1/tag" | ${lib.getExe pkgs.jq} -r .id)
          fi
          printf '%s\n' "$id"
        }

        tag_ids() {
          ${lib.getExe pkgs.jq} -r '.tags[]?' | while IFS= read -r label; do
            tag_id "$label"
          done | ${lib.getExe pkgs.jq} --raw-input '.' | ${lib.getExe pkgs.jq} --slurp 'map(tonumber)'
        }

        ready=0
        for _ in $(${lib.getExe' pkgs.coreutils "seq"} 1 60); do
          api_key=$(${xml} sel -t -v /Config/ApiKey "$config" 2>/dev/null || true)
          if [ -n "$api_key" ] && ${lib.getExe pkgs.curl} --fail --silent --show-error \
            --header "X-Api-Key: $api_key" \
            "$prowlarr_url/api/v1/system/status" >/dev/null; then
            ready=1
            break
          fi
          ${lib.getExe' pkgs.coreutils "sleep"} 1
        done

        if [ "$ready" != 1 ]; then
          printf 'Prowlarr API is not ready\n' >&2
          exit 1
        fi

        ${lib.getExe pkgs.jq} --exit-status 'type == "array"' "$indexers" >/dev/null

        ${lib.getExe pkgs.jq} -c '.[]' "$indexers" | while IFS= read -r indexer; do
          name=$(printf '%s' "$indexer" | ${lib.getExe pkgs.jq} -r .name)
          ids=$(printf '%s' "$indexer" | tag_ids)
          current=$(request GET indexer | ${lib.getExe pkgs.jq} -c \
            --arg name "$name" \
            'map(select(.name == $name)) | first // empty')

          if [ -n "$current" ]; then
            id=$(printf '%s' "$current" | ${lib.getExe pkgs.jq} -r .id)
            base=$current
          else
            id=
            definition=$(printf '%s' "$indexer" | ${lib.getExe pkgs.jq} -r '.definitionName // .implementationName')
            base=$(request GET indexer/schema | ${lib.getExe pkgs.jq} -c \
              --arg definition "$definition" \
              '[.. | objects | select(.definitionName? == $definition or .implementationName? == $definition)] | first // error("indexer schema not found")')
          fi

          missing=$(printf '%s' "$indexer" | ${lib.getExe pkgs.jq} -r \
            --argjson base "$base" \
            '[.fields[]?.name] - [$base.fields[]?.name] | join(", ")')
          if [ -n "$missing" ]; then
            printf '%s has unknown Prowlarr fields: %s\n' "$name" "$missing" >&2
            exit 1
          fi

          payload=$(printf '%s' "$indexer" | ${lib.getExe pkgs.jq} \
            --argjson base "$base" \
            --argjson tags "$ids" \
            '$base as $base | . as $desired | ($desired.fields // []) as $fields | $base + $desired + {
              tags: $tags,
              fields: ($base.fields | map(. as $field | ([$fields[] | select(.name == $field.name)] | first) as $override | if $override == null then $field else $field + { value: $override.value } end))
            }')

          if [ -n "$id" ]; then
            printf '%s' "$payload" | send PUT "indexer/$id"
          else
            printf '%s' "$payload" | send POST indexer
          fi
        done
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
        prowlarr.indexersFile = mkOption { type = types.str; };
      };

      config = mkIf cfg.enable (mkMerge [
        {
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
        }
        (mkIf config.services.prowlarr.enable {
          systemd.services.prowlarr-configure = {
            description = "Configure Prowlarr";
            wantedBy = [ "multi-user.target" ];
            wants = [ "sops-install-secrets.service" ];
            requires = [ "prowlarr.service" ];
            after = [
              "sops-install-secrets.service"
              "prowlarr.service"
            ];
            restartTriggers = [ prowlarrConfigure ];
            serviceConfig = {
              Type = "oneshot";
              LoadCredential = [ "indexers:${cfg.prowlarr.indexersFile}" ];
              ExecStart = prowlarrConfigure;
            };
          };
        })
      ]);
    };
}
