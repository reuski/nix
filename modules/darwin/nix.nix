{ ... }:
{
  flake.modules.darwin.nix =
    {
      config,
      pkgs,
      ...
    }:
    let
      autoSwitch = pkgs.writeShellApplication {
        name = "darwin-auto-switch";
        runtimeInputs = [
          config.system.build.darwin-rebuild
          pkgs.coreutils
        ];
        text = ''
          set -eu

          lock=/var/run/darwin-auto-switch.lock
          if ! mkdir "$lock" 2>/dev/null; then
            exit 0
          fi
          trap 'rmdir "$lock" 2>/dev/null || true' EXIT

          export HOME=/var/root
          darwin-rebuild switch --flake github:reuski/nix/main#${config.networking.hostName} --refresh --option tarball-ttl 0
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
      };

      environment.systemPackages = [ autoSwitch ];

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
        command = "/run/current-system/sw/bin/darwin-auto-switch";
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
