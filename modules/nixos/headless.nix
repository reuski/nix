{ ... }:
{
  flake.modules.nixos.headless =
    { lib, pkgs, ... }:
    {
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

      documentation.enable = false;
      programs.command-not-found.enable = false;
      programs.nano.enable = false;
      fonts = {
        enableDefaultPackages = false;
        packages = [ pkgs.dejavu_fonts.minimal ];
        fontconfig.enable = true;
      };
      xdg.icons.enable = false;
      xdg.mime.enable = false;
      xdg.sounds.enable = false;
      system.disableInstallerTools = true;

      environment.defaultPackages = [ ];
      environment.systemPackages = with pkgs; [
        curl
        dnsutils
        ghostty-terminfo
        git
        jq
        lsof
        ncurses
        rsync
        tcpdump
      ];

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
