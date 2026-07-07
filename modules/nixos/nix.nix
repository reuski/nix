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
        substituters =
          lib.optional (config.networking.hostName != "ukko") "https://ukko.tail2fc4c2.ts.net:8090/ukko"
          ++ [
            "https://noctalia.cachix.org"
            "https://vicinae.cachix.org"
            "https://ghostty.cachix.org"
          ];
        trusted-public-keys =
          lib.optional (
            config.networking.hostName != "ukko"
          ) "ukko:NjZT4Lc1JJvioCv4z6Qv8zDmX+v25+e2r/9qGjTzHkU="
          ++ [
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
            "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
            "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
          ];
        auto-optimise-store = true;
      };

      nix.gc = {
        automatic = true;
        dates = lib.mkDefault "weekly";
        options = lib.mkDefault "--delete-older-than 7d";
      };

      system.autoUpgrade = {
        enable = true;
        flake = "github:reuski/nix/main#${config.networking.hostName}";
        flags = [
          "--option"
          "tarball-ttl"
          "0"
        ];
        dates = lib.mkDefault "03:00";
        randomizedDelaySec = "45min";
        persistent = true;
      };
    };
}
