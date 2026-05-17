{ ... }:
{
  flake.modules.nixos.common =
    { pkgs, ... }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;
      boot.tmp.cleanOnBoot = true;

      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
      };

      systemd.oomd.enable = true;

      users.mutableUsers = false;
      users.users.root.hashedPassword = "!";

      programs.fish.enable = true;

      security.sudo.enable = false;
      security.sudo-rs = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };
    };
}
