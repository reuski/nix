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
      inherit (lib) mkOption types;
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
        "-DLLAMA_BUILD_TESTS=OFF"
        "-DLLAMA_BUILD_EXAMPLES=OFF"
        "-DLLAMA_BUILD_APP=OFF"
        "-DLLAMA_BUILD_UI=OFF"
        "-DGGML_LTO=ON"
        "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
        "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
      ];
      backendCmakeFlags =
        if isDarwin then
          [
            "-DGGML_METAL_NDEBUG=ON"
            "-DGGML_OPENMP=OFF"
            "-DCMAKE_OSX_ARCHITECTURES=arm64"
            "-DCMAKE_C_COMPILER=/usr/bin/clang"
            "-DCMAKE_CXX_COMPILER=/usr/bin/clang++"
          ]
        else
          [
            "-DGGML_CUDA=ON"
            "-DCMAKE_CUDA_ARCHITECTURES=native"
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
        context = 0;
        parallel = -1;
      };
      serverArgs = [
        "--hf-repo"
        cfg.model.repo
        "--hf-file"
        cfg.model.file
        "--alias"
        "local"
        "--gpu-layers"
        "all"
        "--flash-attn"
        "on"
        "--cache-type-k"
        cfg.params.cacheType
        "--cache-type-v"
        cfg.params.cacheType
        "--reasoning-format"
        "deepseek"
        "--reasoning-preserve"
        "--metrics"
        "--temp"
        "1.0"
        "--top-k"
        "20"
        "--top-p"
        "0.95"
        "--min-p"
        "0"
        "--no-ui"
      ]
      ++ optionalChangedArg cfg.host llamaCppDefaults.host "--host"
      ++ optionalChangedArg cfg.port llamaCppDefaults.port "--port"
      ++ optionalChangedArg cfg.params.context llamaCppDefaults.context "--ctx-size"
      ++ optionalChangedArg cfg.params.parallel llamaCppDefaults.parallel "--parallel"
      ++ optionalArg (cfg.model.mmproj == null) [ "--no-mmproj" ]
      ++ optionalArg (cfg.model.mmproj != null) [
        "--mmproj-url"
        "https://huggingface.co/${cfg.model.repo}/resolve/main/${cfg.model.mmproj}"
      ]
      ++ [
        "--reasoning-budget"
        (toString cfg.params.reasoningBudget)
      ];

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

          if git -C "$llama_dir" fetch --depth=1 origin master; then
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
          build_stamp="$build_dir/.pi-build-id"
          server="$build_dir/bin/llama-server"
          cmake_flags=(
          ${shellArrayItems cmakeFlags}
          )

          if [ "$(cat "$build_stamp" 2>/dev/null || true)" != "$build_id" ] || [ ! -x "$server" ]; then
            git -C "$llama_dir" reset --hard "$target"
            git -C "$llama_dir" clean -fdx
            cmake --fresh -S "$llama_dir" -B "$build_dir" -G Ninja "''${cmake_flags[@]}"
            cmake --build "$build_dir" --target llama-server --parallel
            printf '%s\n' "$build_id" >"$build_stamp"
          fi

          ${lib.optionalString (cfg.model.chatTemplate != null) ''
            chat_template="$cache_root/pi/chat-template.jinja"
            chat_template_tmp="$chat_template.$$"
            curl --fail --location --silent --show-error \
              ${lib.escapeShellArg cfg.model.chatTemplate} \
              --output "$chat_template_tmp"
            if [ ! -e "$chat_template" ] || ! cmp --silent "$chat_template" "$chat_template_tmp"; then
              mv "$chat_template_tmp" "$chat_template"
            else
              rm "$chat_template_tmp"
            fi
          ''}

          flock --unlock "$source_lock_fd"
          exec {source_lock_fd}>&-

          args=(
          ${shellArrayItems serverArgs}
          )
          ${lib.optionalString (cfg.model.chatTemplate != null) ''
            args+=(--chat-template-file "$chat_template")
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
        model = {
          repo = mkOption { type = types.str; };
          file = mkOption { type = types.str; };
          mmproj = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          chatTemplate = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
        };
        port = mkOption {
          type = types.port;
          default = 8080;
        };
        params = {
          context = mkOption {
            type = types.ints.positive;
            default = 65536;
          };
          parallel = mkOption {
            type = types.ints.positive;
            default = 1;
          };
          cacheType = mkOption {
            type = types.enum [
              "f16"
              "q8_0"
            ];
            default = "f16";
          };
          reasoningBudget = mkOption {
            type = types.ints.positive;
            default = 8192;
          };
        };
      };

      config.home.packages = [ llama ];
    };
}
