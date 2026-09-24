{
  config,
  lib,
  pkgs,
  ...
}:
let
  protonVariants = {
    CachyOS = pkgs.proton-cachyos;
    GE = pkgs.proton-ge-bin;
    CachyOS-LinUwUx = pkgs.proton-cachyos-linuwux;
  };
in
{
  programs.steam.extraCompatPackages = builtins.attrValues protonVariants;
  environment.systemPackages = [ pkgs.umu-launcher ];

  home-manager.users.${config.profile.username}.xdg.dataFile = lib.mapAttrs' (
    name: package:
    lib.nameValuePair "Steam/compatibilitytools.d/Nix-Proton-${name}" {
      source = package.steamcompattool;
    }
  ) protonVariants;
}
