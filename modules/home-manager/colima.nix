{ ... }:
{
  flake.modules.homeManager.colima =
    { pkgs, ... }:
    let
      limaFull = pkgs.lima-full.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.llvmPackages.lld ];
        NIX_CFLAGS_LINK = "-fuse-ld=${pkgs.llvmPackages.lld}/bin/ld64.lld";
      });
    in
    {
      home.packages = [ (pkgs.colima.override { lima-full = limaFull; }) ];
    };
}
