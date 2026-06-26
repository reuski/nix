{ lib, ... }:
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
          src,
          hash,
        }:
        stdenvNoCC.mkDerivation {
          name = "bun-deps";
          inherit src;
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
          buildPhase = ''
            export HOME=$TMPDIR
            export BUN_INSTALL_CACHE_DIR=$TMPDIR/cache
            bun install --frozen-lockfile --no-progress
          '';
          installPhase = ''
            cp -r node_modules $out
          '';
        };

      bunApp =
        {
          pname,
          version,
          owner,
          repo,
          rev,
          hash,
          depsHash,
          buildScript ? "build",
          installPhase,
        }:
        stdenvNoCC.mkDerivation (
          finalAttrs:
          let
            src = fetchFromGitHub {
              inherit
                owner
                repo
                rev
                hash
                ;
            };
            deps = bunDeps {
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
              ln -s ${deps} node_modules
              runHook postConfigure
            '';
            buildPhase = ''
              runHook preBuild
              export HOME=$TMPDIR
              export BUN_INSTALL_CACHE_DIR=$TMPDIR/cache
              bun run ${lib.escapeShellArg buildScript}
              runHook postBuild
            '';
            installPhase = ''
              nodeModules=${deps}
              runHook preInstall
              ${installPhase}
              runHook postInstall
            '';
            passthru.deps = deps;
          }
        );
    in
    {
      web-reuski-dev = bunApp {
        pname = "reuski-dev";
        version = "unstable-2026-02-16";
        owner = "reuski";
        repo = "reuski.dev";
        rev = "7c6f35d22c09ebe2e531b0df338c11af92a700ae";
        hash = lib.fakeHash;
        depsHash = lib.fakeHash;
        installPhase = ''
          cp -r _site $out
        '';
      };

      web-beebud = bunApp {
        pname = "beebud";
        version = "unstable-2026-05-15";
        owner = "reuski";
        repo = "beebud";
        rev = "33c8d43bf595680358c46c04120782e97786944a";
        hash = lib.fakeHash;
        depsHash = lib.fakeHash;
        installPhase = ''
          mkdir -p $out
          cp -r build $out/build
          ln -s "$nodeModules" $out/node_modules
          makeWrapper ${lib.getExe bun} $out/bin/web-beebud \
            --add-flags "$out/build/index.js"
        '';
      };

      web-wahuu-games = bunApp {
        pname = "wahuu-games";
        version = "unstable-2026-05-10";
        owner = "reuski";
        repo = "wahuu.games";
        rev = "2188815f57a49e4319fc0852e796a598a03aa1f4";
        hash = lib.fakeHash;
        depsHash = lib.fakeHash;
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
