{ ... }:
{
  flake.modules.nixos.home-assistant =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.homeAssistant;
      inherit (lib)
        mkIf
        mkOption
        types
        ;

      port = 8123;
      base = "http://127.0.0.1:${toString port}";
      clientId = "${base}/";

      setupScript = pkgs.writeShellScript "home-assistant-setup" ''
        set -euo pipefail

        base=${base}
        client_id=${clientId}
        name=${lib.escapeShellArg cfg.admin.name}
        username=${lib.escapeShellArg cfg.admin.username}
        password=$(tr -d '\r\n' < "$CREDENTIALS_DIRECTORY/admin-password")
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT

        if [ -z "$password" ]; then
          printf 'Home Assistant admin password is empty\n' >&2
          exit 1
        fi

        code=""
        for _ in $(seq 1 300); do
          code=$(curl --silent --output "$tmp/onboarding.json" --write-out '%{http_code}' "$base/api/onboarding" || true)
          case "$code" in
            200) break ;;
            404) exit 0 ;;
            *) sleep 1 ;;
          esac
        done

        if [ "$code" != "200" ]; then
          printf 'Home Assistant onboarding endpoint not ready (last status: %s)\n' "$code" >&2
          exit 1
        fi

        if jq --exit-status 'any(.[]; .step == "user" and .done)' "$tmp/onboarding.json" >/dev/null; then
          exit 0
        fi

        jq -nc \
          --arg client_id "$client_id" \
          --arg name "$name" \
          --arg username "$username" \
          --arg password "$password" \
          '{client_id:$client_id, name:$name, username:$username, password:$password, language:"en"}' \
          | curl --fail --silent --show-error -H 'Content-Type: application/json' \
              -X POST "$base/api/onboarding/users" --data-binary @- > "$tmp/user.json"

        auth_code=$(jq -r '.auth_code // empty' "$tmp/user.json")
        if [ -z "$auth_code" ]; then
          printf 'Home Assistant onboarding did not return an auth code\n' >&2
          exit 1
        fi

        token=$(curl --fail --silent --show-error -X POST "$base/auth/token" \
          --data-urlencode "client_id=$client_id" \
          --data-urlencode "grant_type=authorization_code" \
          --data-urlencode "code=$auth_code" \
          | jq -r '.access_token // empty')
        if [ -z "$token" ]; then
          printf 'Home Assistant token exchange failed\n' >&2
          exit 1
        fi

        auth() {
          curl --fail --silent --show-error -H "Authorization: Bearer $token" "$@"
        }

        auth -X POST "$base/api/onboarding/core_config" >/dev/null
        auth -X POST "$base/api/onboarding/analytics" >/dev/null
        jq -nc --arg client_id "$client_id" '{client_id:$client_id, redirect_uri:$client_id}' \
          | auth -H 'Content-Type: application/json' \
              -X POST "$base/api/onboarding/integration" --data-binary @- >/dev/null
      '';
    in
    {
      options.homeAssistant = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        admin = {
          name = mkOption {
            type = types.str;
            default = config.profile.fullName;
          };
          username = mkOption {
            type = types.str;
            default = config.profile.username;
          };
          passwordFile = mkOption { type = types.str; };
        };
        components = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        settings = mkOption {
          type = types.attrs;
          default = { };
        };
      };

      config = mkIf cfg.enable {
        services.home-assistant = {
          enable = true;
          extraComponents = [ "default_config" ] ++ cfg.components;
          config = lib.recursiveUpdate {
            default_config = { };
            http = {
              server_host = [ "127.0.0.1" ];
              use_x_forwarded_for = true;
              trusted_proxies = [
                "127.0.0.1"
                "::1"
              ];
            };
          } cfg.settings;
        };

        proxy.services.home.port = port;

        systemd.services.home-assistant-setup = {
          description = "Complete Home Assistant onboarding";
          wantedBy = [ "multi-user.target" ];
          wants = [
            "home-assistant.service"
            "network-online.target"
          ];
          requires = [ "home-assistant.service" ];
          after = [
            "home-assistant.service"
            "network-online.target"
            "sops-install-secrets.service"
          ];
          path = with pkgs; [
            coreutils
            curl
            jq
          ];
          unitConfig = {
            ConditionPathExists = cfg.admin.passwordFile;
            StartLimitIntervalSec = "5min";
            StartLimitBurst = 5;
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            LoadCredential = [ "admin-password:${cfg.admin.passwordFile}" ];
            ExecStart = setupScript;
            Restart = "on-failure";
            RestartSec = "10s";
            TimeoutStartSec = "10min";
          };
        };
      };
    };
}
