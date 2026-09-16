{ ... }:
{
  flake.overlays.proton =
    final: _prev:
    let
      mkProton =
        {
          pname,
          version,
          url,
          hash,
          upstreamName,
          displayName,
          description,
          homepage,
          license,
          sourceRoot ? "",
        }:
        final.stdenvNoCC.mkDerivation {
          inherit pname version sourceRoot;

          src = final.fetchurl {
            inherit url hash;
            name = "${version}.tar.xz";
          };

          outputs = [
            "out"
            "steamcompattool"
          ];

          installPhase = ''
            runHook preInstall

            mkdir -p "$steamcompattool"
            cp -a . "$steamcompattool/"

            substituteInPlace "$steamcompattool/compatibilitytool.vdf" \
              --replace-fail '"${upstreamName}" // Internal name' '"${displayName}" // Internal name' \
              --replace-fail '"display_name" "${upstreamName}"' '"display_name" "${displayName}"'

            echo "Use the steamcompattool output via programs.steam.extraCompatPackages." > "$out"

            runHook postInstall
          '';

          dontFixup = true;

          meta = {
            inherit description homepage license;
            platforms = [ "x86_64-linux" ];
            sourceProvenance = [ final.lib.sourceTypes.binaryNativeCode ];
          };
        };
    in
    {
      proton-cachyos = mkProton rec {
        pname = "proton-cachyos";
        version = "cachyos-11.0-20260703-slr";
        url = "https://github.com/CachyOS/proton-cachyos/releases/download/${version}/proton-${version}-x86_64_v3.tar.xz";
        hash = "sha256-A+zUK9fUdOm6RDzoly2WeKH6Osvykg12HzU5eUbs4oQ=";
        upstreamName = "proton-${version}-x86_64_v3";
        displayName = "Proton CachyOS x86_64-v3";
        description = "CachyOS Proton build for the Steam Linux Runtime (x86-64-v3)";
        homepage = "https://github.com/CachyOS/proton-cachyos";
        license = final.lib.licenses.bsd3;
      };

      proton-cachyos-linuwux = mkProton rec {
        pname = "proton-cachyos-linuwux";
        version = "proton-cachyos-11.0-20260703-slr-LinUwUx-Rework";
        url = "https://sourceforge.net/projects/proton-linuwux/files/Proton-CachyOS%20LinUwUx/${version}.tar.xz/download";
        hash = "sha256-MJTXBiyykIpg3orJugUFYgf2Lmh/BD7fuB4sAceic/w=";
        upstreamName = version;
        displayName = "Proton CachyOS LinUwUx";
        description = "Proton-CachyOS build patched with LinUwUx.patch";
        homepage = "https://codeberg.org/xshaduwulfx/proton-linuwux";
        license = with final.lib.licenses; [
          bsd3
          lgpl21Plus
          mit
        ];
        sourceRoot = ".";
      };
    };
}
