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
      cfg = config.media.jellyfin;
      inherit (lib)
        concatLists
        mapAttrsToList
        mkIf
        mkOption
        optionalAttrs
        types
        unique
        ;

      libraryType = types.submodule (
        { name, ... }:
        {
          options = {
            title = mkOption {
              type = types.str;
              default = name;
            };
            collectionType = mkOption {
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
        }
      );

      libraries = mapAttrsToList (_name: library: {
        name = library.title;
        type = library.collectionType;
        paths = library.paths;
      }) cfg.libraries;
      librariesFile = pkgs.writeText "jellyfin-libraries.json" (builtins.toJSON libraries);
      libraryPaths = unique (concatLists (mapAttrsToList (_name: library: library.paths) cfg.libraries));
      libraryTitles = map (library: library.name) libraries;
      intelPackages = builtins.filter (package: package != null) [
        (pkgs.intel-media-driver or null)
        (pkgs.intel-compute-runtime or null)
      ];
      setupScript = pkgs.writeShellScript "jellyfin-setup" ''
        set -euo pipefail

        base=${lib.escapeShellArg cfg.url}
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
          api -X POST "$base/Startup/RemoteAccess" --data '{"EnableRemoteAccess":false,"EnableAutomaticPortMapping":false}' >/dev/null
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
          | jq '.EnableUPnP = false | .EnableRemoteAccess = false | .EnableQuickConnect = false | .UICulture = "en-US" | .MetadataCountryCode = "FI" | .PreferredMetadataLanguage = "en"' \
          > "$tmp/system.json"
        api_auth -X POST "$base/System/Configuration" --data-binary "@$tmp/system.json" >/dev/null

        api_auth "$base/System/Configuration/encoding" \
          | jq '.TranscodingTempPath = "/var/cache/jellyfin/transcodes" | .HardwareAccelerationType = "qsv" | .EnableHardwareEncoding = true | .EnableDecodingColorDepth10Hevc = true | .EnableDecodingColorDepth10Vp9 = true | .EnableDecodingColorDepth10Av1 = true | .AllowHevcEncoding = true | .AllowAv1Encoding = false | .EnableTonemapping = true | .EnableVppTonemapping = true | .TonemappingAlgorithm = "bt2390" | .TonemappingMode = "auto" | .TonemappingRange = "auto" | .EncodingThreadCount = 0 | .EnableSubtitleExtraction = true | .DeinterlaceMethod = "yadif"' \
          > "$tmp/encoding.json"
        api_auth -X POST "$base/System/Configuration/encoding" --data-binary "@$tmp/encoding.json" >/dev/null

        api_auth "$base/Library/VirtualFolders" > "$tmp/folders.json"
        jq -c '.[]' ${librariesFile} | while IFS= read -r library; do
          name=$(jq -r '.name' <<< "$library")
          type=$(jq -r '.type' <<< "$library")
          paths=$(jq -c '.paths' <<< "$library")

          name_uri=$(jq -rn --arg value "$name" '$value | @uri')

          if jq --exit-status --arg name "$name" 'any(.[]; .Name == $name)' "$tmp/folders.json" >/dev/null; then
            jq -r '.paths[]' <<< "$library" | while IFS= read -r path; do
              if jq --exit-status --arg name "$name" --arg path "$path" 'any(.[]; .Name == $name and (((.Locations // []) + ((.LibraryOptions.PathInfos // []) | map(.Path))) | any(. == $path)))' "$tmp/folders.json" >/dev/null; then
                continue
              fi

              jq -nc --arg path "$path" '{Path:$path}' \
                | api_auth -X POST "$base/Library/VirtualFolders/Paths?name=$name_uri" --data-binary @- >/dev/null
            done
            continue
          fi

          type_uri=$(jq -rn --arg value "$type" '$value | @uri')
          payload=$(jq -nc --argjson paths "$paths" '{LibraryOptions:{EnableRealtimeMonitor:true, EnableChapterImageExtraction:false, PathInfos: ($paths | map({Path:.}))}}')
          api_auth -X POST "$base/Library/VirtualFolders?name=$name_uri&collectionType=$type_uri&refreshLibrary=true" --data "$payload" >/dev/null
        done

        api_auth -X POST "$base/Library/Refresh" --data '{}' >/dev/null || true
      '';
    in
    {
      options.media.jellyfin = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        group = mkOption {
          type = types.str;
          default = "media";
        };
        url = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8096";
        };
        openFirewall = mkOption {
          type = types.bool;
          default = true;
        };
        proxy.enable = mkOption {
          type = types.bool;
          default = true;
        };
        hardwareAcceleration = mkOption {
          type = types.enum [ "intel-qsv" ];
          default = "intel-qsv";
        };
        admin = {
          name = mkOption {
            type = types.str;
            default = config.profile.username;
          };
          passwordFile = mkOption { type = types.str; };
        };
        libraries = mkOption {
          type = types.attrsOf libraryType;
          default = { };
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = builtins.length libraryTitles == builtins.length (unique libraryTitles);
            message = "media.jellyfin library titles must be unique.";
          }
        ];

        services.jellyfin = {
          enable = true;
          group = cfg.group;
          openFirewall = cfg.openFirewall;
        };

        proxy.services = mkIf cfg.proxy.enable {
          jellyfin.port = 8096;
        };

        networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [
          1900
          7359
        ];

        hardware.graphics = {
          enable = true;
          extraPackages = mkIf (cfg.hardwareAcceleration == "intel-qsv") intelPackages;
        };

        environment.sessionVariables.LIBVA_DRIVER_NAME = mkIf (cfg.hardwareAcceleration == "intel-qsv") "iHD";

        fonts = {
          fontconfig.enable = true;
          packages = with pkgs; [
            liberation_ttf
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
          ];
        };

        boot.kernel.sysctl = {
          "fs.inotify.max_user_instances" = 1024;
          "fs.inotify.max_user_watches" = 1048576;
        };

        users.groups.${cfg.group} = { };
        users.users = {
          jellyfin.extraGroups = [
            cfg.group
            "render"
            "video"
          ];
          ${config.profile.username}.extraGroups = [ cfg.group ];
        };

        systemd.tmpfiles.rules =
          [
            "d /srv/media 2775 ${config.profile.username} ${cfg.group} -"
            "d /var/cache/jellyfin/transcodes 0750 jellyfin ${cfg.group} -"
          ]
          ++ map (path: "d ${path} 2775 ${config.profile.username} ${cfg.group} -") libraryPaths;

        systemd.services = {
          jellyfin = {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            environment = optionalAttrs (cfg.hardwareAcceleration == "intel-qsv") {
              LIBVA_DRIVER_NAME = "iHD";
            };
            serviceConfig = {
              UMask = lib.mkForce "0002";
              SupplementaryGroups = [
                cfg.group
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
            unitConfig.ConditionPathExists = cfg.admin.passwordFile;
            serviceConfig = {
              Type = "oneshot";
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
