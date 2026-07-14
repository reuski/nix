{ ... }:
{
  flake.modules.homeManager.colima =
    { pkgs, ... }:
    let
      limaFull = pkgs.lima-full.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.llvmPackages.lld ];
        NIX_CFLAGS_LINK = "-fuse-ld=${pkgs.llvmPackages.lld}/bin/ld64.lld";
      });
      colima = (pkgs.colima.override { lima-full = limaFull; }).overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          wrapProgram $out/bin/colima --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.docker-client ]}
        '';
      });
    in
    {
      home.packages = [ colima ];
    };
}
