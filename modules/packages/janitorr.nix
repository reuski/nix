{ lib, ... }:
let
  version = "2.1.0";

  fetchGhcrLayer =
    final: name: digest: hash:
    final.stdenvNoCC.mkDerivation {
      name = "janitorr-${version}-${name}";
      dontUnpack = true;
      nativeBuildInputs = [
        final.curl
        final.jq
      ];
      buildCommand = ''
        token=$(curl -sf "https://ghcr.io/token?service=ghcr.io&scope=repository:schaka/janitorr:pull" | jq -r '.token')
        curl -sfL -H "Authorization: Bearer $token" \
          "https://ghcr.io/v2/schaka/janitorr/blobs/sha256:${digest}" \
          -o "$out"
      '';
      outputHashMode = "flat";
      outputHash = hash;
    };
in
{
  flake.overlays.janitorr =
    final: _prev:
    let
      appLayer = fetchGhcrLayer final "app-layer" "a8abd45c9dfe021e8cc1b8382c9d2d33f6f575f8d59addaf740b6160fe2d4b06" "sha256-qKvUXJ3+Ah6Mwbg4LJ0tM/b1dfjVmt2vdAthYP4tSwY=";
      scbLayer = fetchGhcrLayer final "scb-layer" "856ce222bf03dce9f17e4e0271376b0841bbaa2e62e723c8b138cbfbc9e822f6" "sha256-hWziIr8D3Onxfk4CcTdrCEG7qi5i5yPIsTjL+8noIvY=";
    in
    {
      janitorr = final.callPackage (
        {
          stdenvNoCC,
          gnutar,
          makeWrapper,
          jdk25,
        }:
        stdenvNoCC.mkDerivation {
          pname = "janitorr";
          inherit version;

          dontUnpack = true;

          nativeBuildInputs = [
            gnutar
            makeWrapper
          ];

          buildPhase = ''
            mkdir -p app lib
            tar xzf ${appLayer} --strip-components=1 -C app/
            tar xzf ${scbLayer} --strip-components=3 -C lib/
          '';

          installPhase = ''
            mkdir -p $out/lib $out/bin
            cp app/runner.jar $out/
            cp app/lib/*.jar $out/lib/
            cp lib/spring-cloud-bindings-2.0.4.jar $out/lib/

            makeWrapper ${jdk25}/bin/java $out/bin/janitorr \
              --add-flags "-cp $out/runner.jar:$out/lib/spring-cloud-bindings-2.0.4.jar" \
              --add-flags "com.github.schaka.janitorr.JanitorrApplicationKt"
          '';

          meta = {
            description = "Cleans up media library based on watch history";
            homepage = "https://github.com/Schaka/janitorr";
            license = lib.licenses.gpl3Only;
            platforms = lib.platforms.linux;
            mainProgram = "janitorr";
          };
        }
      ) { };
    };
}
