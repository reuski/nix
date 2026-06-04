{ inputs, lib, ... }:
{
  flake.overlays.upstream =
    _final: prev:
    let
      inherit (prev.stdenv.hostPlatform) isLinux system;
    in
    lib.optionalAttrs isLinux {
      ghostty = inputs.ghostty.packages.${system}.default;
      noctalia-shell = inputs.noctalia.packages.${system}.default;
      vicinae = inputs.vicinae.packages.${system}.default;
    };
}
