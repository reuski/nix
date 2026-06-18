{ inputs, lib, ... }:
{
  flake.overlays.upstream =
    final: prev:
    let
      inherit (prev.stdenv.hostPlatform) isLinux system;
    in
    lib.optionalAttrs isLinux {
      ghostty = inputs.ghostty.packages.${system}.default;
      ghostty-terminfo = final.ghostty.terminfo;
      noctalia = inputs.noctalia.packages.${system}.default;
      vicinae = inputs.vicinae.packages.${system}.default;
    };
}
