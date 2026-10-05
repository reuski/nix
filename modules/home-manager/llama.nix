{ ... }:
{
  flake.modules.homeManager.llama =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.llama;
      inherit (lib) mkEnableOption mkOption types;
      inherit (pkgs.stdenv.hostPlatform) isDarwin;

      cp = pkgs.cudaPackages;
      toolchain = cp.backendStdenv.cc;
      tls = pkgs.openssl;

      cudaInc = lib.concatStringsSep ":" [
        "${lib.getDev cp.cuda_cudart}/include"
        "${lib.getDev cp.cccl}/include"
        "${cp.libcublas.include}/include"
      ];
      cudaLib = lib.makeLibraryPath [
        (lib.getLib cp.cuda_cudart)
        (lib.getLib cp.libcublas)
      ];
      cudaRoots = lib.concatStringsSep ":" [
        "${lib.getDev cp.cuda_cudart}"
        "${lib.getLib cp.libcublas}"
        "${lib.getDev cp.cccl}"
        "${cp.cuda_nvcc}"
      ];
      runLibPath = lib.concatStringsSep ":" (
        [ "${lib.getLib tls}/lib" ]
        ++ lib.optionals (!isDarwin) [
          "/run/opengl-driver/lib"
          cudaLib
        ]
      );

      baseCmakeFlags = [
        "-DBUILD_SHARED_LIBS=OFF"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DLLAMA_BUILD_TESTS=OFF"
        "-DLLAMA_BUILD_EXAMPLES=OFF"
        "-DLLAMA_BUILD_APP=OFF"
        "-DLLAMA_BUILD_SERVER=ON"
        "-DGGML_LTO=ON"
        "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
        "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
      ];
      backendCmakeFlags =
        if isDarwin then
          [
            "-DGGML_METAL_EMBED_LIBRARY=ON"
            "-DGGML_METAL_NDEBUG=ON"
            "-DGGML_OPENMP=OFF"
            "-DCMAKE_OSX_ARCHITECTURES=arm64"
            "-DCMAKE_C_COMPILER=/usr/bin/clang"
            "-DCMAKE_CXX_COMPILER=/usr/bin/clang++"
          ]
        else
          [
            "-DGGML_CUDA=ON"
            "-DCMAKE_CUDA_ARCHITECTURES=${cfg.build.cudaArchitectures}"
            "-DCMAKE_CUDA_COMPILER_LAUNCHER=ccache"
          ];
      cmakeFlags = baseCmakeFlags ++ backendCmakeFlags;

      shellArrayItems =
        values: lib.concatStringsSep "\n" (map (value: "            ${lib.escapeShellArg value}") values);
      optionalArg = condition: values: lib.optionals condition values;
      optionalChangedArg =
        value: default: flag:
        optionalArg (value != default) [
          flag
          (toString value)
        ];
      llamaCppDefaults = {
        host = "127.0.0.1";
        port = 8080;
      };
      validPresetValue =
        value:
        !(builtins.isString value)
        || (
          builtins.match "[^\r\n#;]*" value != null
          && !(lib.hasPrefix " " value)
          && !(lib.hasPrefix "\t" value)
          && !(lib.hasSuffix " " value)
          && !(lib.hasSuffix "\t" value)
        );
      validPresetKey = key: builtins.match "[a-zA-Z_][a-zA-Z0-9_.-]*" key != null;
      presetSectionType =
        types.addCheck
          (types.attrsOf (
            types.oneOf [
              types.bool
              types.int
              types.float
              types.str
            ]
          ))
          (
            section:
            builtins.all (key: validPresetKey key && validPresetValue section.${key}) (
              builtins.attrNames section
            )
          );
      validModelName = name: name != "default" && builtins.match "[A-Za-z0-9_.-]+" name != null;
      modelsType = types.addCheck (types.attrsOf presetSectionType) (
        models: models != { } && builtins.all validModelName (builtins.attrNames models)
      );
      defaultPreset = {
        gpu-layers = "all";
        flash-attn = "on";
        fit = "off";
        parallel = 1;
        cache-type-k = "f16";
        cache-type-v = "f16";
        load-on-startup = false;
      };
      presetFile = pkgs.writeText "llama-models.ini" (
        lib.generators.toINI { } ({ "*" = cfg.defaults; } // cfg.models)
      );
      serverArgs = [
        "--models-preset"
        "${presetFile}"
        "--models-max"
        "1"
        "--models-autoload"
        "--metrics"
      ]
      ++ optionalArg (!cfg.ui) [ "--no-ui" ]
      ++ optionalChangedArg cfg.host llamaCppDefaults.host "--host"
      ++ optionalChangedArg cfg.port llamaCppDefaults.port "--port";

      buildEnv = ''
        export CMAKE_PREFIX_PATH="${lib.getDev tls}:${lib.getLib tls}''${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
        export LD_LIBRARY_PATH="${runLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export DYLD_LIBRARY_PATH="${runLibPath}''${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
        ${
          if isDarwin then
            ''
              export CC="/usr/bin/clang"
              export CXX="/usr/bin/clang++"
            ''
          else
            ''
              export CC="${lib.getExe' toolchain "gcc"}"
              export CXX="${lib.getExe' toolchain "g++"}"
            ''
        }
      '';

      cudaEnv = lib.optionalString (!isDarwin) ''
        export CUDACXX="${lib.getExe' cp.cuda_nvcc "nvcc"}"
        export CUDAHOSTCXX="${lib.getExe' cp.backendStdenv.cc "g++"}"
        export CPATH="${cudaInc}''${CPATH:+:$CPATH}"
        export LIBRARY_PATH="${cudaLib}''${LIBRARY_PATH:+:$LIBRARY_PATH}"
        export CUDAToolkit_ROOT="${cudaRoots}"
      '';

      runtimeInputs =
        with pkgs;
        [
          ccache
          cmake
          coreutils
          curl
          flock
          git
          ninja
        ]
        ++ lib.optionals (!isDarwin) [
          toolchain
          cp.cuda_nvcc
          cp.cccl
          cp.cuda_cudart
          cp.libcublas
        ];
      buildHash = builtins.hashString "sha256" (
        builtins.toJSON {
          inherit
            buildEnv
            cmakeFlags
            cudaEnv
            ;
          runtimeInputs = map toString runtimeInputs;
        }
      );

      llama = pkgs.writeShellApplication {
        name = "llama-server";
        inherit runtimeInputs;
        text = ''
          ${buildEnv}
          ${cudaEnv}
          cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}"
          llama_dir="$cache_root/pi/llama.cpp"
          source_lock="$cache_root/pi/llama.cpp.lock"
          export LLAMA_CACHE="''${LLAMA_CACHE:-$cache_root/llama.cpp-models}"
          mkdir -p "$cache_root/pi"

          exec {source_lock_fd}>"$source_lock"
          if ! flock --exclusive --timeout 1800 "$source_lock_fd"; then
            echo "timed out waiting for llama.cpp source lock: $source_lock" >&2
            exit 1
          fi

          if [ ! -d "$llama_dir/.git" ]; then
            mkdir -p "$llama_dir"
            git -C "$llama_dir" init -q
            git -C "$llama_dir" remote add origin https://github.com/ggml-org/llama.cpp.git
          fi

          if git -C "$llama_dir" fetch --depth=1 origin HEAD; then
            target="$(git -C "$llama_dir" rev-parse FETCH_HEAD)"
          elif git -C "$llama_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
            echo "llama.cpp fetch failed; using cached source" >&2
            target="$(git -C "$llama_dir" rev-parse HEAD)"
          else
            echo "llama.cpp fetch failed and no cached source is available" >&2
            exit 1
          fi

          compiler_id="$("$CXX" --version | cksum | cut -d ' ' -f 1)"
          build_id="${buildHash}-$compiler_id-$target"
          build_dir="$cache_root/pi/llama.cpp-build"
          build_stamp="$cache_root/pi/llama-server.build-id"
          built_server="$build_dir/bin/llama-server"
          server="$cache_root/pi/llama-server"
          cmake_flags=(
          ${shellArrayItems cmakeFlags}
          )

          if [ "$(cat "$build_stamp" 2>/dev/null || true)" != "$build_id" ] || [ ! -x "$server" ]; then
            if git -C "$llama_dir" reset --hard "$target" \
              && git -C "$llama_dir" clean -fdx \
              && cmake --fresh -S "$llama_dir" -B "$build_dir" -G Ninja "''${cmake_flags[@]}" \
              && cmake --build "$build_dir" --target llama-server --parallel; then
              server_tmp="$server.$$"
              build_stamp_tmp="$build_stamp.$$"
              install -m 0755 "$built_server" "$server_tmp"
              printf '%s\n' "$build_id" >"$build_stamp_tmp"
              mv "$server_tmp" "$server"
              mv "$build_stamp_tmp" "$build_stamp"
            elif [ -x "$server" ]; then
              echo "llama.cpp update failed for $target; using cached server" >&2
            else
              echo "llama.cpp update failed and no cached server is available" >&2
              exit 1
            fi
          fi

          flock --unlock "$source_lock_fd"
          exec {source_lock_fd}>&-

          args=(
          ${shellArrayItems serverArgs}
          )
          ${lib.optionalString (cfg.extraArgs != [ ]) ''
            args+=(
            ${shellArrayItems cfg.extraArgs}
            )
          ''}

          exec "$server" "''${args[@]}" "$@"
        '';
        meta = {
          description = "Local llama-server";
          mainProgram = "llama-server";
          platforms = pkgs.lib.platforms.darwin ++ pkgs.lib.platforms.linux;
        };
      };
    in
    {
      options.llama = {
        build.cudaArchitectures = mkOption {
          type = types.str;
          default = "native";
          description = "CUDA architectures passed to CMake";
        };
        models = mkOption {
          type = modelsType;
          default = { };
          description = "Named llama.cpp model presets with scalar option values";
        };
        defaults = mkOption {
          type = presetSectionType;
          default = { };
          apply = overrides: defaultPreset // overrides;
          description = "Shared llama.cpp preset defaults with per-key overrides";
        };
        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
        };
        port = mkOption {
          type = types.port;
          default = 8080;
        };
        ui = mkEnableOption "the built-in llama-server Web UI";
        extraArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Router CLI overrides applied before user arguments";
        };
      };

      config.home.packages = [ llama ];
    };
}
