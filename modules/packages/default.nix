{ config, lib, ... }:
{
  flake.overlays.default = lib.composeManyExtensions [
    config.flake.overlays.upstream
    config.flake.overlays.helium-browser
    config.flake.overlays.python-validity
    config.flake.overlays.pi
  ];

  perSystem =
    { pkgs, system, ... }:
    {
      packages = {
        inherit (pkgs) pi-coding-agent pi-acp;
      }
      // lib.optionalAttrs (lib.hasSuffix "-linux" system) {
        inherit (pkgs) helium-browser python-validity;
      };
    };
}
