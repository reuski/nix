{ inputs, lib, ... }:
{
  flake.overlays.upstream =
    final: _prev:
    let
      sys = final.stdenv.hostPlatform.system;
    in
    lib.optionalAttrs final.stdenv.hostPlatform.isLinux {
      noctalia-shell = inputs.noctalia.packages.${sys}.default;
      vicinae = inputs.vicinae.packages.${sys}.default;
    };
}
