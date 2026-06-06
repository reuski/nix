{ ... }:
{
  flake.modules.nixos.tiny =
    { lib, pkgs, ... }:
    let
      journalctl = lib.getExe' pkgs.systemd "journalctl";
      nixCollectGarbage = lib.getExe' pkgs.nix "nix-collect-garbage";
    in
    {
      nix.settings = {
        max-jobs = 1;
        cores = 1;
        min-free = 512 * 1024 * 1024;
        max-free = 2048 * 1024 * 1024;
      };

      nix.gc = {
        dates = "daily";
        options = "--delete-old";
      };

      nix.daemonIOSchedClass = "idle";

      boot.loader.grub.configurationLimit = 2;

      boot.kernel.sysctl = {
        "vm.swappiness" = 180;
        "vm.page-cluster" = 0;
      };

      zramSwap.memoryPercent = lib.mkForce 100;

      services.journald.extraConfig = lib.mkForce ''
        SystemMaxUse=100M
        RuntimeMaxUse=50M
        MaxRetentionSec=2week
      '';

      system.autoUpgrade.operation = "boot";
      systemd.services.nixos-upgrade.preStart = ''
        ${journalctl} --vacuum-size=50M
        ${nixCollectGarbage} --delete-old
      '';
    };
}
