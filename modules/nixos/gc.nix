{ ... }:
{
  flake.modules.nixos.gc =
    { lib, ... }:
    {
      nix.gc = {
        automatic = true;
        dates = lib.mkDefault "weekly";
        options = lib.mkDefault "--delete-older-than 7d";
      };
    };
}
