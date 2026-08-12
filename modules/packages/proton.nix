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
        }:
        final.stdenvNoCC.mkDerivation {
          inherit pname version;

          src = final.fetchurl { inherit url hash; };

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
        url = "https://github.com/xshaduwulfx/proton-linuwux/releases/download/${version}/${version}.tar.gz";
        hash = "sha256-I/ON0yqV0el9/x0dGcsQVQK0ZdZ9/U+WITLYVpGhaus=";
        upstreamName = version;
        displayName = "Proton CachyOS LinUwUx";
        description = "Proton-CachyOS build patched with LinUwUx.patch";
        homepage = "https://github.com/xshaduwulfx/proton-linuwux";
        license = with final.lib.licenses; [
          bsd3
          lgpl21Plus
          mit
        ];
      };
    };
}
