{ config, ... }:
{
  flake.modules.darwin.fonts =
    { pkgs, ... }:
    {
      fonts.packages = config.fontSet.packages pkgs;
    };
}
