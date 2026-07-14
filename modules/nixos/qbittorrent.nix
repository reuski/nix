{ ... }:
{
  flake.modules.nixos.qbittorrent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.qbittorrent;
      media = config.media;
      quadlet = config.virtualisation.quadlet;
      inherit (lib)
        getExe
        getExe'
        mkEnableOption
        mkIf
        mkOption
        types
        ;
      port = toString cfg.webuiPort;
      qbtSetPortUp = "/bin/sh -c 'wget -qO- --retry-connrefused --timeout=10 --post-data \"json={\\\"listen_port\\\":{{PORT}},\\\"current_network_interface\\\":\\\"{{VPN_INTERFACE}}\\\",\\\"random_port\\\":false,\\\"upnp\\\":false}\" http://127.0.0.1:${port}/api/v2/app/setPreferences'";
      qbtSetPortDown = "/bin/sh -c 'wget -qO- --retry-connrefused --timeout=10 --post-data \"json={\\\"listen_port\\\":0,\\\"current_network_interface\\\":\\\"lo\\\"}\" http://127.0.0.1:${port}/api/v2/app/setPreferences'";
      piaCa = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/pia-foss/manual-connections/master/ca.rsa.4096.crt";
        hash = "sha256-Mumx0UM+qXYU8qFMbjWOP1fAVwzJ9rLugSaZumlsZqs=";
      };
      piaWireguardConfig = pkgs.writeShellApplication {
        name = "pia-wireguard-config";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gnugrep
          jq
          wireguard-tools
        ];
        text = ''
          credentials=${lib.escapeShellArg cfg.environmentFile}
          region=${lib.escapeShellArg cfg.region}
          runtime=/run/gluetun

          env_value() {
            grep -m1 "^$1=" "$credentials" | cut -d= -f2-
          }

          PIA_USER=$(env_value PIA_USER)
          PIA_PASS=$(env_value PIA_PASS)
          test -n "$PIA_USER"
          test -n "$PIA_PASS"

          install -d -m 0700 "$runtime" "$runtime/wireguard"
          rm -f /var/lib/gluetun/piaportforward.json
          curl_flags=(--fail --silent --show-error --location --connect-timeout 10 --retry 15 --retry-delay 2 --retry-all-errors)

          token_response=$(curl "''${curl_flags[@]}" --request POST \
            --form "username=$PIA_USER" \
            --form "password=$PIA_PASS" \
            https://www.privateinternetaccess.com/api/client/v2/token)
          token=$(printf '%s' "$token_response" | jq -er .token)

          regions=$(curl "''${curl_flags[@]}" https://serverlist.piaservers.net/vpninfo/servers/v6 | head -n1)
          region_data=$(printf '%s' "$regions" | jq -er --arg region "$region" '.regions[] | select(.id == $region) | select(.port_forward == true)')
          server_ip=$(printf '%s' "$region_data" | jq -er '.servers.wg[0].ip')
          server_host=$(printf '%s' "$region_data" | jq -er '.servers.wg[0].cn')

          private_key=$(wg genkey)
          public_key=$(printf '%s' "$private_key" | wg pubkey)
          wireguard_response=$(curl "''${curl_flags[@]}" --get \
            --connect-to "$server_host::$server_ip:" \
            --cacert ${piaCa} \
            --data-urlencode "pt=$token" \
            --data-urlencode "pubkey=$public_key" \
            "https://$server_host:1337/addKey")
          test "$(printf '%s' "$wireguard_response" | jq -er .status)" = OK

          config_tmp=$(mktemp "$runtime/wireguard/wg0.conf.XXXXXX")
          env_tmp=$(mktemp "$runtime/pia-wireguard.env.XXXXXX")
          chmod 0400 "$config_tmp" "$env_tmp"

          cat >"$config_tmp" <<EOF
          [Interface]
          Address = $(printf '%s' "$wireguard_response" | jq -er .peer_ip)
          PrivateKey = $private_key

          [Peer]
          PersistentKeepalive = 25
          PublicKey = $(printf '%s' "$wireguard_response" | jq -er .server_key)
          AllowedIPs = 0.0.0.0/0
          Endpoint = $server_ip:$(printf '%s' "$wireguard_response" | jq -er .server_port)
          EOF

          printf 'SERVER_NAMES=%s\n' "''${server_host%%.*}" >"$env_tmp"
          mv "$config_tmp" "$runtime/wireguard/wg0.conf"
          mv "$env_tmp" "$runtime/pia-wireguard.env"
        '';
      };
    in
    {
      options.qbittorrent = {
        enable = mkEnableOption "qBittorrent behind the PIA VPN pod";
        webuiPort = mkOption {
          type = types.port;
          default = 8080;
        };
        downloadDir = mkOption {
          type = types.str;
          default = "${media.libraryDir}/torrents";
          description = "Torrent download/seed dir; under libraryDir so it shares the media filesystem (hardlinks) and relocates with it.";
        };
        environmentFile = mkOption {
          type = types.str;
          description = "PIA credentials and gluetun port-forwarding env file, sops secret path.";
        };
        region = mkOption {
          type = types.str;
          default = "nl_amsterdam";
        };
      };

      config = mkIf cfg.enable {
        virtualisation.quadlet = {
          pods.vpn.podConfig.publishPorts = [ "127.0.0.1:${port}:${port}" ];

          containers.gluetun = {
            containerConfig = {
              image = "ghcr.io/qdm12/gluetun:latest";
              name = "gluetun";
              pod = quadlet.pods.vpn.ref;
              addCapabilities = [ "NET_ADMIN" ];
              devices = [ "/dev/net/tun" ];
              autoUpdate = "registry";
              startWithPod = true;
              healthCmd = "wget -q -O /dev/null --timeout=10 http://127.0.0.1:9999/";
              healthInterval = "1m";
              healthRetries = 5;
              healthTimeout = "15s";
              healthStartPeriod = "40s";
              environments = {
                VPN_SERVICE_PROVIDER = "custom";
                VPN_TYPE = "wireguard";
                VPN_PORT_FORWARDING = "on";
                VPN_PORT_FORWARDING_PROVIDER = "private internet access";
                VPN_PORT_FORWARDING_UP_COMMAND = qbtSetPortUp;
                VPN_PORT_FORWARDING_DOWN_COMMAND = qbtSetPortDown;
                FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24";
                TZ = config.profile.timeZone;
              };
              environmentFiles = [
                cfg.environmentFile
                "/run/gluetun/pia-wireguard.env"
              ];
              volumes = [
                "/var/lib/gluetun:/gluetun"
                "/run/gluetun/wireguard:/gluetun/wireguard:ro"
              ];
            };
            unitConfig = {
              After = [
                "adguardhome.service"
                "network-online.target"
              ];
              Wants = [
                "adguardhome.service"
                "network-online.target"
              ];
            };
          };

          containers.qbittorrent = {
            containerConfig = {
              image = "lscr.io/linuxserver/qbittorrent:latest";
              name = "qbittorrent";
              pod = quadlet.pods.vpn.ref;
              autoUpdate = "registry";
              startWithPod = true;
              environments = media.containerEnv // {
                WEBUI_PORT = port;
              };
              volumes = [
                "/var/lib/qbittorrent:/config"
                "${cfg.downloadDir}:${cfg.downloadDir}"
              ];
            };
            unitConfig = {
              After = [ "gluetun.service" ];
              Requires = [ "gluetun.service" ];
              BindsTo = [ "gluetun.service" ];
            };
          };
        };

        proxy.services.qbittorrent.port = cfg.webuiPort;

        systemd.services.gluetun.serviceConfig.ExecStartPre = getExe piaWireguardConfig;

        systemd.services.qbittorrent-refresh = {
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${getExe' pkgs.systemd "systemctl"} restart vpn-pod.service";
          };
        };

        systemd.timers.qbittorrent-refresh = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "5m";
          };
        };

        media.directories = {
          "/var/lib/gluetun".mode = "0750";
          "/var/lib/qbittorrent".mode = "0755";
          ${cfg.downloadDir} = { };
        };
      };
    };
}
