{ ... }:
{
  flake.modules.darwin.nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      autoSwitch = pkgs.writeShellApplication {
        name = "darwin-auto-switch";
        runtimeInputs = [
          pkgs.coreutils
        ];
        text = ''
          set -eu

          lock=/var/run/darwin-auto-switch.lock
          acquired=0
          if mkdir "$lock" 2>/dev/null; then
            acquired=1
          else
            pid=
            if [ -s "$lock/pid" ]; then
              pid=$(cat "$lock/pid" 2>/dev/null || true)
            fi
            case "$pid" in
              ""|*[!0-9]*) ;;
              *)
                if kill -0 "$pid" 2>/dev/null; then
                  exit 0
                fi
                ;;
            esac

            rm -f "$lock/pid" 2>/dev/null || true
            rmdir "$lock" 2>/dev/null || true
            if mkdir "$lock" 2>/dev/null; then
              acquired=1
            fi
          fi
          if [ "$acquired" != 1 ]; then
            exit 0
          fi
          trap 'rm -f "$lock/pid" 2>/dev/null || true; rmdir "$lock" 2>/dev/null || true' EXIT
          printf '%s\n' "$$" > "$lock/pid"

          export HOME=/var/root
          ${lib.getExe config.system.build.darwin-rebuild} switch --flake github:reuski/nix/main#${config.networking.hostName} --refresh --option tarball-ttl 0
        '';
      };
    in
    {
      nix.enable = true;
      nix.package = pkgs.nix;
      nix.channel.enable = false;
      nix.nixPath = [ ];

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ "@admin" ];
        extra-substituters = [ "https://reuski.cachix.org" ];
        extra-trusted-public-keys = [
          "reuski.cachix.org-1:eIWz4qd8JPuIm9XZxbfSQ802IhhJv2EarUiIG0IXSTs="
        ];
      };

      nix.gc = {
        automatic = true;
        interval = [
          {
            Weekday = 7;
            Hour = 3;
            Minute = 15;
          }
        ];
        options = "--delete-older-than 7d";
      };

      nix.optimise = {
        automatic = true;
        interval = [
          {
            Weekday = 7;
            Hour = 4;
            Minute = 15;
          }
        ];
      };

      launchd.daemons.darwin-auto-switch = {
        command = lib.getExe autoSwitch;
        serviceConfig = {
          RunAtLoad = false;
          StartCalendarInterval = [
            {
              Hour = 4;
              Minute = 30;
            }
          ];
          StandardOutPath = "/var/log/darwin-auto-switch.log";
          StandardErrorPath = "/var/log/darwin-auto-switch.err.log";
          Nice = 19;
          LowPriorityIO = true;
          ProcessType = "Background";
        };
      };
    };
}
