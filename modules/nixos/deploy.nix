{ ... }:
{
  flake.modules.nixos.deploy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.deploy;
      flake = "github:reuski/nix/main";

      pipeline = pkgs.writeShellApplication {
        name = "deploy";
        runtimeInputs = [
          config.nix.package
          pkgs.nixos-rebuild
          pkgs.openssh
          pkgs.attic-client
        ];
        text = ''
          export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"

          warm() {
            out=$(nix build "${flake}#nixosConfigurations.$1.config.system.build.toplevel" \
              --refresh --option tarball-ttl 0 --no-link --print-out-paths)
            attic push "${cfg.cache}" "$out"
          }

          activate() {
            nixos-rebuild switch --flake "${flake}#$1" \
              --target-host "root@$1" --refresh --option tarball-ttl 0
          }

          reboot_if_stale() {
            ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "root@$1" '
              booted=$(readlink /run/booted-system/{kernel,initrd,kernel-modules})
              built=$(readlink /run/current-system/{kernel,initrd,kernel-modules})
              [ "$booted" = "$built" ] || systemctl reboot'
          }

          for host in ${lib.escapeShellArgs cfg.warm}; do
            warm "$host"
          done

          for host in ${lib.escapeShellArgs cfg.targets}; do
            activate "$host" || activate "$host"
            reboot_if_stale "$host"
          done
        '';
      };
    in
    {
      options.deploy = {
        cache = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Local Attic cache that built closures are pushed into.";
        };
        warm = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Hosts whose closures are built and cached for self-upgrade pull (no remote activation).";
        };
        targets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Hosts this machine builds, pushes, and activates over Tailscale SSH (MagicDNS names).";
        };
      };

      config = lib.mkIf (cfg.warm != [ ] || cfg.targets != [ ]) {
        systemd.services.deploy = {
          description = "Build, cache, and deploy host closures";
          after = [
            "network-online.target"
            "tailscaled.service"
            "atticd.service"
          ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            Environment = "HOME=/root";
            ExecStart = lib.getExe pipeline;
          };
        };
        systemd.timers.deploy = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "22:00";
            RandomizedDelaySec = "30min";
            Persistent = true;
          };
        };
      };
    };
}
