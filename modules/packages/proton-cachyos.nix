{ ... }:
{
  flake.overlays.proton-cachyos = final: _prev: {
    proton-cachyos = final.callPackage (
      {
        lib,
        stdenvNoCC,
        fetchurl,
      }:

      stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "proton-cachyos";
        version = "cachyos-11.0-20260703-slr";

        src = fetchurl {
          url = "https://github.com/CachyOS/proton-cachyos/releases/download/${finalAttrs.version}/proton-${finalAttrs.version}-x86_64_v3.tar.xz";
          hash = "sha256-A+zUK9fUdOm6RDzoly2WeKH6Osvykg12HzU5eUbs4oQ=";
        };

        outputs = [
          "out"
          "steamcompattool"
        ];

        installPhase = ''
          runHook preInstall

          mkdir -p "$steamcompattool"
          cp -a . "$steamcompattool/"

          sed -i -r 's|"display_name"[[:space:]]+"[^"]*"|"display_name" "Proton CachyOS x86_64-v3"|' \
            "$steamcompattool/compatibilitytool.vdf"
          sed -i -r 's|"proton-cachyos-[^"]*"([[:space:]]*// Internal name)|"Proton CachyOS x86_64-v3"\1|' \
            "$steamcompattool/compatibilitytool.vdf"

          echo "Use the steamcompattool output via programs.steam.extraCompatPackages." > "$out"

          runHook postInstall
        '';

        dontFixup = true;

        meta = {
          description = "CachyOS Proton build for the Steam Linux Runtime (x86-64-v3)";
          homepage = "https://github.com/CachyOS/proton-cachyos";
          license = lib.licenses.bsd3;
          platforms = [ "x86_64-linux" ];
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        };
      })
    ) { };
  };
}
