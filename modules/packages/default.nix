{ config, lib, ... }:
{
  flake.overlays.default = lib.composeManyExtensions [
    config.flake.overlays.upstream
    config.flake.overlays.helium-browser
    config.flake.overlays.python-validity
    config.flake.overlays.zjstatus
  ];

  perSystem =
    { pkgs, system, ... }:
    {
      packages =
        { inherit (pkgs) zjstatus; }
        // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
          inherit (pkgs) helium-browser python-validity;
        };
    };
}
