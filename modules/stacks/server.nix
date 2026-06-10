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
        nixos.base
        nixos.networkd
        nixos.ssh
        nixos.hardening
        nixos.locale
        nixos.secrets
        nixos.vim
        nixos.nix
        nixos.tailscale
      ];

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
