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
      deployFor =
        host:
        pkgs.writeShellApplication {
          name = "deploy-${host}";
          runtimeInputs = [
            config.nix.package
            pkgs.nixos-rebuild
            pkgs.openssh
          ];
          text = ''
            export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new -o BatchMode=yes"
            deploy() {
              nixos-rebuild switch \
                --flake "github:reuski/nix/main#${host}" \
                --target-host "root@${host}" \
                --refresh --option tarball-ttl 0
            }
            deploy || deploy
            ssh $NIX_SSHOPTS "root@${host}" '
              booted=$(readlink /run/booted-system/{kernel,initrd,kernel-modules})
              built=$(readlink /run/current-system/{kernel,initrd,kernel-modules})
              [ "$booted" = "$built" ] || systemctl reboot
            '
          '';
        };
      mkUnits =
        f:
        builtins.listToAttrs (
          map (host: {
            name = "deploy-${host}";
            value = f host;
          }) cfg.targets
        );
    in
    {
      options.deploy.targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Hosts this machine remotely builds, pushes, and activates over Tailscale SSH (MagicDNS names).";
      };

      config = lib.mkIf (cfg.targets != [ ]) {
        systemd.services = mkUnits (host: {
          description = "Build and deploy ${host}";
          after = [
            "network-online.target"
            "tailscaled.service"
          ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe (deployFor host);
          };
        });
        systemd.timers = mkUnits (_: {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "04:30";
            RandomizedDelaySec = "30min";
            Persistent = true;
          };
        });
      };
    };
}
