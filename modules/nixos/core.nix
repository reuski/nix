{ ... }:
{
  flake.modules.nixos.core =
    { config, pkgs, ... }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;
      boot.tmp.cleanOnBoot = true;

      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
      };

      systemd.oomd.enable = true;

      services.fstrim.enable = true;
      services.timesyncd.enable = true;

      services.journald.extraConfig = ''
        SystemMaxUse=500M
        RuntimeMaxUse=100M
        MaxRetentionSec=1month
      '';

      documentation.nixos.enable = false;
      documentation.man.cache.enable = false;

      users.mutableUsers = false;
      users.users.root.hashedPassword = "!";
      users.users.${config.profile.username} = {
        isNormalUser = true;
        description = config.profile.fullName;
        home = config.profile.homeDirectory;
        extraGroups = [ "wheel" ];
      };

      security.sudo.enable = false;
      security.sudo-rs = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };
    };
}
