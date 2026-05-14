{ inputs, ... }:
{
  flake.modules.nixos.nix =
    { config, ... }:
    {
      nix.channel.enable = false;
      nix.registry.nixpkgs.flake = inputs.nixpkgs;
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
        download-buffer-size = 536870912;
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

      system.autoUpgrade = {
        enable = true;
        flake = "github:reuski/nix/main#${config.networking.hostName}";
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
}
