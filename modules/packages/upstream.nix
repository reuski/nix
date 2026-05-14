{ inputs, ... }:
{
  flake.overlays.upstream = final: _prev: {
    noctalia-shell = inputs.noctalia.packages.${final.stdenv.hostPlatform.system}.default;
    vicinae = inputs.vicinae.packages.${final.stdenv.hostPlatform.system}.default;
  };
}
