{ ... }:
{
  flake.modules.nixos.nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.site.autoUpgradeFlake = lib.mkOption {
        type = lib.types.str;
        default = "github:reuski/nix/main";
        description = "Flake reference for system auto-upgrade.";
      };

      config = {
        nix.channel.enable = false;
        nix.registry.nixpkgs.to = {
          type = "path";
          path = pkgs.path;
        };
        nix.nixPath = [ ];

        nix.settings = {
          max-jobs = "auto";
          cores = 0;
          builders-use-substitutes = true;
          connect-timeout = 5;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [ "@wheel" ];
          substituters = [ "https://cache.nixos.org" ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          ];
        };

        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

        nix.optimise = {
          automatic = true;
          dates = "weekly";
        };

        nix.settings.auto-optimise-store = true;

        system.autoUpgrade = {
          enable = true;
          flake = "${config.site.autoUpgradeFlake}#${config.networking.hostName}";
          flags = [
            "--refresh"
            "--option"
            "tarball-ttl"
            "0"
          ];
          dates = "daily";
          randomizedDelaySec = "45min";
          persistent = true;
        };

        systemd.services.nixos-upgrade.serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5min";
        };
      };
    };
}
