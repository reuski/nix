{ lib, ... }:
{
  flake.modules.nixos.cachix = {
    nix.settings = {
      substituters = lib.mkAfter [
        "https://noctalia.cachix.org"
        "https://vicinae.cachix.org"
        "https://ghostty.cachix.org"
      ];
      trusted-public-keys = lib.mkAfter [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
        "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      ];
    };
  };
}
