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
      cfg = config.media.qbittorrent;
      media = config.media;
      quadlet = config.virtualisation.quadlet;
      inherit (lib)
        getExe
        mkIf
        mkOption
        types
        ;
      port = toString cfg.webuiPort;
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
          curl_flags=(--fail --silent --show-error --location --retry 3 --retry-delay 1 --retry-all-errors)

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
      options.media.qbittorrent = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        webuiPort = mkOption {
          type = types.port;
          default = 8080;
        };
        downloadDir = mkOption {
          type = types.str;
          default = "/srv/media/torrents";
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
              environments = {
                VPN_SERVICE_PROVIDER = "custom";
                VPN_TYPE = "wireguard";
                VPN_PORT_FORWARDING = "on";
                VPN_PORT_FORWARDING_PROVIDER = "private internet access";
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
          };

          containers.qbittorrent = {
            containerConfig = {
              image = "lscr.io/linuxserver/qbittorrent:latest";
              name = "qbittorrent";
              pod = quadlet.pods.vpn.ref;
              autoUpdate = "registry";
              environments = media.containerEnv // {
                WEBUI_PORT = port;
              };
              volumes = [
                "/var/lib/qbittorrent:/config"
                "${media.libraryDir}:${media.libraryDir}"
              ];
            };
            unitConfig = {
              After = [ quadlet.containers.gluetun.ref ];
              Requires = [ quadlet.containers.gluetun.ref ];
              BindsTo = [ quadlet.containers.gluetun.ref ];
            };
          };
        };

        proxy.services.qbittorrent.port = cfg.webuiPort;

        systemd.services.gluetun.serviceConfig.ExecStartPre = getExe piaWireguardConfig;

        systemd.tmpfiles.rules = [
          "d /var/lib/gluetun 0750 ${media.user} ${media.group} -"
          "d /var/lib/qbittorrent 0755 ${media.user} ${media.group} -"
          "d ${cfg.downloadDir} 2775 ${media.user} ${media.group} -"
        ];
      };
    };
}
