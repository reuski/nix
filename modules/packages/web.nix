{
  inputs,
  lib,
  ...
}:
{
  flake.overlays.web =
    final: _prev:
    let
      inherit (final)
        bun
        cacert
        fetchFromGitHub
        makeWrapper
        stdenvNoCC
        ;

      bunDeps =
        {
          name,
          src,
          hash,
        }:
        stdenvNoCC.mkDerivation {
          inherit
            name
            src
            ;
          nativeBuildInputs = [
            bun
            cacert
          ];
          impureEnvVars = lib.fetchers.proxyImpureEnvVars;
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = hash;
          dontConfigure = true;
          dontFixup = true;
          dontBuild = true;
          installPhase = ''
            export HOME=$TMPDIR
            bun install --frozen-lockfile --no-progress --ignore-scripts
            mkdir -p $out
            cp -r node_modules $out/
          '';
        };

      bunApp =
        {
          pname,
          version,
          src,
          depsHash,
          buildCommand ? "bun run build",
          installPhase,
        }:
        stdenvNoCC.mkDerivation (
          finalAttrs:
          let
            deps = bunDeps {
              name = "${pname}-${finalAttrs.version}-bun-deps";
              inherit src;
              hash = finalAttrs.depsHash;
            };
          in
          {
            inherit
              pname
              version
              src
              ;
            depsHash = depsHash;
            nativeBuildInputs = [
              bun
              makeWrapper
            ];
            NODE_ENV = "production";
            configurePhase = ''
              runHook preConfigure
              ln -s ${deps}/node_modules node_modules
              runHook postConfigure
            '';
            buildPhase = ''
              runHook preBuild
              export HOME=$TMPDIR
              export BUN_INSTALL_CACHE_DIR=$TMPDIR/cache
              ${buildCommand}
              runHook postBuild
            '';
            installPhase = ''
              nodeModules=${deps}/node_modules
              runHook preInstall
              ${installPhase}
              runHook postInstall
            '';
            passthru.npmDeps = deps;
          }
        );
    in
    {
      web-reuski-dev = bunApp {
        pname = "reuski-dev";
        version = "0-unstable-2026-06-30";
        src = fetchFromGitHub {
          owner = "reuski";
          repo = "reuski.dev";
          rev = "910b001d50553d4957bc982aee63de726ba59fe2";
          hash = "sha256-j7v4qEjofg6EH99Tdb6vOHq1iPo9VrpJPJJlXEvdklI=";
        };
        depsHash = "sha256-KIsFYH+6fAIUZ7ZdryBZDA7RIw5+M+/DHtHXD2HY2+U=";
        installPhase = ''
          cp -r _site $out
        '';
      };

      web-beebud = bunApp {
        pname = "beebud";
        version = "0-unstable-2026-06-30";
        src = fetchFromGitHub {
          owner = "reuski";
          repo = "beebud";
          rev = "a18d639d655c3d4d827e96663b44b4d80fe31a6e";
          hash = "sha256-6YYxqx7rPlu4JgZAIganb8TIqf82lyXyW2m12s3wXyI=";
        };
        depsHash = "sha256-kWm3thvDSgxodii94PHKFE7YvF+xi01/ADW9xz6PwqI=";
        installPhase = ''
          mkdir -p $out
          cp -r build $out/build
          ln -s "$nodeModules" $out/node_modules
          makeWrapper ${lib.getExe bun} $out/bin/web-beebud \
            --add-flags "$out/build/index.js"
        '';
      };

      web-juttu = bunApp {
        pname = "juttu";
        version = "0-unstable-${builtins.substring 0 7 (inputs.juttu.rev or "unknown")}";
        src = inputs.juttu.outPath;
        depsHash = "sha256-1KKPGHDLzhB7NKDcP2VILWbI6zjVDuzzXGXbmoEHHIQ=";
        buildCommand = "bun ./node_modules/vite/bin/vite.js build";
        installPhase = ''
          mkdir -p $out
          cp -r build $out/build
          ln -s "$nodeModules" $out/node_modules
          makeWrapper ${lib.getExe bun} $out/bin/web-juttu \
            --add-flags "$out/build/index.js"
        '';
      };

      web-wahuu-games = bunApp {
        pname = "wahuu-games";
        version = "0-unstable-2026-08-21";
        src = fetchFromGitHub {
          owner = "reuski";
          repo = "wahuu.games";
          rev = "a03e3ce42142b3c6f09b841691d3ec86a1aaa674";
          hash = "sha256-ESfV+PD0VogT1/3L0oVUcB6ahFGwSWFmYlJg8YdHhGA=";
        };
        depsHash = "sha256-6OlNNRGbdcQ/pI1HySGO5rl4U3q/5VRFCREBQeut5Co=";
        installPhase = ''
          mkdir -p $out/bin
          cp -r src dist index.html $out/
          ln -s "$nodeModules" $out/node_modules
          makeWrapper ${lib.getExe bun} $out/bin/web-wahuu-games \
            --add-flags "$out/src/server/index.ts"
        '';
      };
    };
}
