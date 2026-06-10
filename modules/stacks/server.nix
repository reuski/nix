{ config, ... }:
let
  inherit (config.flake.modules) generic nixos;
in
{
  flake.modules.nixos.server =
    { lib, pkgs, ... }:
    {
      imports = [
        generic.profile
        nixos.nixpkgs
        nixos.common
        nixos.networkd
        nixos.ssh
        nixos.hardening
        nixos.headless
        nixos.locale
        nixos.secrets
        nixos.vim
        nixos.nix
        nixos.tailscale
      ];

      boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

      # Keep the nightly on-box upgrade build from starving running services.
      nix.daemonIOSchedClass = "idle";
      systemd.services.nixos-upgrade.serviceConfig = {
        Nice = 19;
        IOSchedulingClass = "idle";
      };

      system.autoUpgrade = {
        allowReboot = true;
        dates = "04:00";
        rebootWindow = {
          lower = "04:00";
          upper = "06:00";
        };
      };
    };
}
