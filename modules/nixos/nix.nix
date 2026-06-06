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
      nix.channel.enable = false;
      nix.registry.nixpkgs.to = {
        type = "path";
        path = pkgs.path;
      };
      nix.nixPath = [ ];

      nix.settings = {
        max-jobs = lib.mkDefault "auto";
        cores = lib.mkDefault 0;
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
        auto-optimise-store = true;
      };

      nix.gc = {
        automatic = true;
        dates = lib.mkDefault "weekly";
        options = lib.mkDefault "--delete-older-than 7d";
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
        dates = lib.mkDefault "daily";
        randomizedDelaySec = "45min";
        persistent = true;
      };
    };
}
