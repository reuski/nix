{ inputs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.channel.enable = false;
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

  nix.settings = {
    max-jobs = "auto";
    cores = 0;
    builders-use-substitutes = true;
    connect-timeout = 5;
    fallback = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "@wheel" ];
    download-buffer-size = 536870912;
    substituters = [
      "https://cache.nixos.org"
      "https://niri.cachix.org"
      "https://noctalia.cachix.org"
      "https://vicinae.cachix.org"
      "https://ghostty.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
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
    flake = "github:reuski/nix/main#hiisi";
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
}
