{ ... }:
{
  flake.modules.nixos.jellyfin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.jellyfin;
      mediaGroup = config.media.group;
      inherit (lib)
        concatLists
        genAttrs
        mkEnableOption
        mkIf
        mkOption
        types
        unique
        ;

      libraryType = types.submodule {
        options = {
          name = mkOption { type = types.str; };
          type = mkOption {
            type = types.enum [
              "books"
              "boxsets"
              "homevideos"
              "mixed"
              "movies"
              "music"
              "musicvideos"
              "photos"
              "tvshows"
            ];
            default = "mixed";
          };
          paths = mkOption { type = types.nonEmptyListOf types.str; };
        };
      };

      libraryPaths = unique (concatLists (map (library: library.paths) cfg.libraries));
      libraryNames = map (library: library.name) cfg.libraries;
      librariesFile = pkgs.writeText "jellyfin-libraries.json" (builtins.toJSON cfg.libraries);
      subtitleFontPath = "${pkgs.inter}/share/fonts";
      systemFilter = pkgs.writeText "jellyfin-system.jq" ''
        .QuickConnectAvailable = false
        | .UICulture = "en-US"
        | .MetadataCountryCode = "FI"
        | .PreferredMetadataLanguage = "en"
      '';
      networkFilter = pkgs.writeText "jellyfin-network.jq" ''
        .EnableRemoteAccess = true
        | .EnablePublishedServerUriByRequest = true
        | .LocalNetworkSubnets = [ "192.168.1.0/24" ]
        | .KnownProxies = [ "127.0.0.1" ]
      '';
      encodingFilter = pkgs.writeText "jellyfin-encoding.jq" ''
        .TranscodingTempPath = "/var/cache/jellyfin/transcodes"
        | .HardwareAccelerationType = "qsv"
        | .EnableHardwareEncoding = true
        | .EnableDecodingColorDepth10Hevc = true
        | .EnableDecodingColorDepth10Vp9 = true
        | .EnableDecodingColorDepth10Av1 = true
        | .AllowHevcEncoding = false
        | .AllowAv1Encoding = false
        | .EnableTonemapping = true
        | .EnableVppTonemapping = true
        | .TonemappingAlgorithm = "bt2390"
        | .TonemappingMode = "auto"
        | .TonemappingRange = "auto"
        | .EnableAudioVbr = true
        | .DownMixAudioBoost = 1.0
        | .DownMixStereoAlgorithm = "dave750"
        | .EncodingThreadCount = 0
        | .EnableSubtitleExtraction = true
        | .EnableFallbackFont = true
        | .FallbackFontPath = ${builtins.toJSON subtitleFontPath}
        | .DeinterlaceMethod = "yadif"
      '';
      setupScript = pkgs.writeShellScript "jellyfin-setup" ''
        set -euo pipefail

        base=http://127.0.0.1:8096
        admin=${lib.escapeShellArg cfg.admin.name}
        auth_header='MediaBrowser Client="nix", Device="nixos", DeviceId="nixos-jellyfin-setup", Version="1"'
        password=$(tr -d '\r\n' < "$CREDENTIALS_DIRECTORY/admin-password")
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT

        if [ -z "$password" ]; then
          printf 'Jellyfin admin password is empty\n' >&2
          exit 1
        fi

        api() {
          curl --fail --silent --show-error -H 'Content-Type: application/json' "$@"
        }

        api_auth() {
          api -H "X-Emby-Token: $token" "$@"
        }

        for _ in $(seq 1 120); do
          if curl --fail --silent --show-error "$base/System/Info/Public" >/dev/null; then
            break
          fi
          sleep 1
        done

        curl --fail --silent --show-error "$base/System/Info/Public" > "$tmp/public.json"

        if ! jq --exit-status '.StartupWizardCompleted == true' "$tmp/public.json" >/dev/null; then
          api -X POST "$base/Startup/Configuration" --data '{"UICulture":"en-US","MetadataCountryCode":"FI","PreferredMetadataLanguage":"en"}' >/dev/null
          jq -nc --arg name "$admin" --arg password "$password" '{Name:$name, Password:$password}' \
            | api -X POST "$base/Startup/User" --data-binary @- >/dev/null
          api -X POST "$base/Startup/RemoteAccess" --data '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' >/dev/null
          api -X POST "$base/Startup/Complete" --data '{}' >/dev/null
        fi

        jq -nc --arg username "$admin" --arg password "$password" '{Username:$username, Pw:$password}' \
          | api -X POST "$base/Users/AuthenticateByName" -H "X-Emby-Authorization: $auth_header" --data-binary @- > "$tmp/auth.json"
        token=$(jq -r '.AccessToken // empty' "$tmp/auth.json")
        if [ -z "$token" ]; then
          printf 'Jellyfin authentication did not return a token\n' >&2
          exit 1
        fi

        api_auth "$base/System/Configuration" \
          | jq -f ${systemFilter} \
          > "$tmp/system.json"
        api_auth -X POST "$base/System/Configuration" --data-binary "@$tmp/system.json" >/dev/null

        api_auth "$base/System/Configuration/encoding" \
          | jq -f ${encodingFilter} \
          > "$tmp/encoding.json"
        api_auth -X POST "$base/System/Configuration/encoding" --data-binary "@$tmp/encoding.json" >/dev/null

        api_auth "$base/System/Configuration/network" \
          | jq -f ${networkFilter} \
          > "$tmp/network.json"
        api_auth -X POST "$base/System/Configuration/network" --data-binary "@$tmp/network.json" >/dev/null

        api_auth "$base/Library/VirtualFolders" > "$tmp/folders.json"
        jq -c '.[]' ${librariesFile} | while IFS= read -r library; do
          name=$(jq -r '.name' <<< "$library")
          type=$(jq -r '.type' <<< "$library")
          paths=$(jq -c '.paths' <<< "$library")

          if jq --exit-status --arg name "$name" 'any(.[]; .Name == $name)' "$tmp/folders.json" >/dev/null; then
            continue
          fi

          name_uri=$(jq -rn --arg value "$name" '$value | @uri')
          type_uri=$(jq -rn --arg value "$type" '$value | @uri')
          payload=$(jq -nc --argjson paths "$paths" '{LibraryOptions:{EnableRealtimeMonitor:true, EnableChapterImageExtraction:false, PathInfos: ($paths | map({Path:.}))}}')
          api_auth -X POST "$base/Library/VirtualFolders?name=$name_uri&collectionType=$type_uri&refreshLibrary=true" --data "$payload" >/dev/null
        done

        api_auth -X POST "$base/Library/Refresh" --data '{}' >/dev/null || true
      '';
    in
    {
      options.jellyfin = {
        enable = mkEnableOption "Jellyfin";
        openFirewall = mkOption {
          type = types.bool;
          default = false;
        };
        admin = {
          name = mkOption {
            type = types.str;
            default = config.profile.username;
          };
          passwordFile = mkOption { type = types.str; };
        };
        libraries = mkOption {
          type = types.listOf libraryType;
          default = [ ];
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = builtins.length libraryNames == builtins.length (unique libraryNames);
            message = "jellyfin library names must be unique.";
          }
        ];

        services.jellyfin = {
          enable = true;
          group = mediaGroup;
          openFirewall = cfg.openFirewall;
        };

        proxy.services.jellyfin.port = 8096;

        boot.kernel.sysctl = {
          "fs.inotify.max_user_instances" = 1024;
          "fs.inotify.max_user_watches" = 1048576;
        };

        users.users.jellyfin.extraGroups = [
          mediaGroup
          "render"
          "video"
        ];

        media.directories = {
          "/var/cache/jellyfin/transcodes" = {
            mode = "0750";
            owner = "jellyfin";
          };
        }
        // genAttrs libraryPaths (_: { });

        systemd.services = {
          jellyfin = {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            environment = {
              ASPNETCORE_URLS = "http://127.0.0.1:8096";
              LIBVA_DRIVER_NAME = "iHD";
            };
            serviceConfig = {
              UMask = lib.mkForce "0002";
              SupplementaryGroups = [
                mediaGroup
                "render"
                "video"
              ];
            };
          };

          jellyfin-setup = {
            description = "Initialize Jellyfin";
            wantedBy = [ "multi-user.target" ];
            wants = [
              "jellyfin.service"
              "network-online.target"
            ];
            requires = [ "jellyfin.service" ];
            after = [
              "jellyfin.service"
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
              TimeoutStartSec = "5min";
            };
          };
        };
      };
    };
}
