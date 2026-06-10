{ inputs, lib, ... }:
{
  flake.overlays.upstream =
    _final: prev:
    let
      inherit (prev.stdenv.hostPlatform) isLinux system;
    in
    lib.optionalAttrs isLinux {
      ghostty = inputs.ghostty.packages.${system}.default;
      # Preserve the cached upstream terminfo: headless servers need the
      # xterm-ghostty entry but must not compile the flake ghostty for it.
      ghostty-terminfo = prev.ghostty.terminfo;
      noctalia = inputs.noctalia.packages.${system}.default;
      vicinae = inputs.vicinae.packages.${system}.default;
    };
}
