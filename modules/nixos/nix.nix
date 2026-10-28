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
      nix.settings = {
        nix-path = [ ];
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
          ++ [ "https://reuski.cachix.org" ];
        trusted-public-keys =
          lib.optional (
            config.networking.hostName != "ukko"
          ) "ukko:NjZT4Lc1JJvioCv4z6Qv8zDmX+v25+e2r/9qGjTzHkU="
          ++ [
            "reuski.cachix.org-1:eIWz4qd8JPuIm9XZxbfSQ802IhhJv2EarUiIG0IXSTs="
          ];
        auto-optimise-store = true;
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
