{ config, lib, ... }:
{
  flake.overlays.default = lib.composeManyExtensions [
    config.flake.overlays.upstream
    config.flake.overlays.helium-browser
    config.flake.overlays.python-validity
    config.flake.overlays.pi
    config.flake.overlays.zjstatus
    config.flake.overlays.janitorr
  ];

  perSystem =
    { pkgs, system, ... }:
    {
      packages = {
        inherit (pkgs) pi-acp pi-coding-agent zjstatus;
      }
      // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        inherit (pkgs) helium-browser python-validity;
      };
    };
}
