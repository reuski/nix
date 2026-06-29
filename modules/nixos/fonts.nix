{ config, ... }:
{
  flake.modules.nixos.fonts =
    { pkgs, ... }:
    {
      fonts.enableDefaultPackages = false;
      fonts.packages = config.fontSet.packages pkgs;
      fonts.fontconfig = {
        enable = true;
        defaultFonts = config.fontSet.defaultFonts;
      };
    };
}
