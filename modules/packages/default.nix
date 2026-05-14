{ config, lib, ... }:
{
  flake.overlays.default = lib.composeManyExtensions [
    config.flake.overlays.upstream
    config.flake.overlays.helium-browser
    config.flake.overlays.python-validity
    config.flake.overlays.zjstatus
  ];

  perSystem =
    { pkgs, ... }:
    {
      packages = {
        inherit (pkgs) helium-browser python-validity zjstatus;
      };
    };
}
