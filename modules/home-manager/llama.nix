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
      cmakeFlagsHash = builtins.hashString "sha256" (lib.concatStringsSep "\n" cmakeFlags);

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
        "--min-p"
        "0"
        "--no-ui"
        "--no-slots"
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
      ++ optionalArg (cfg.params.mtpDraftTokens != null) [
        "--spec-type"
        "draft-mtp"
        "--spec-draft-n-max"
        (toString cfg.params.mtpDraftTokens)
      ];

      buildEnv = ''
        export CMAKE_PREFIX_PATH="${lib.getDev tls}:${lib.getLib tls}''${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
        export LD_LIBRARY_PATH="${runLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export DYLD_LIBRARY_PATH="${runLibPath}''${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
        ${lib.optionalString isDarwin ''
          export CC="/usr/bin/clang"
          export CXX="/usr/bin/clang++"
        ''}
      '';

      cudaEnv = lib.optionalString (!isDarwin) ''
        export CUDACXX="${lib.getExe' cp.cuda_nvcc "nvcc"}"
        export CUDAHOSTCXX="${lib.getExe' cp.backendStdenv.cc "g++"}"
        export CPATH="${cudaInc}''${CPATH:+:$CPATH}"
        export LIBRARY_PATH="${cudaLib}''${LIBRARY_PATH:+:$LIBRARY_PATH}"
        export CUDAToolkit_ROOT="${cudaRoots}"
      '';

      llama = pkgs.writeShellApplication {
        name = "llama-server";
        runtimeInputs =
          with pkgs;
          [
            cmake
            ninja
            git
            ccache
          ]
          ++ lib.optionals (!isDarwin) [
            toolchain
            cp.cuda_nvcc
            cp.cccl
            cp.cuda_cudart
            cp.libcublas
          ];
        text = ''
          ${buildEnv}
          ${cudaEnv}
          llama_dir="$HOME/.local/src/llama.cpp"
          build_dir="$llama_dir/build"
          server="$build_dir/bin/llama-server"
          flags_stamp="$build_dir/.pi-cmake-flags-${cmakeFlagsHash}"
          export LLAMA_CACHE="''${LLAMA_CACHE:-$HOME/.cache/llama.cpp}"

          cmake_flags=(
          ${shellArrayItems cmakeFlags}
          )

          build_llama() {
            rm -rf "$build_dir"
            cmake -S "$llama_dir" -B "$build_dir" -G Ninja "''${cmake_flags[@]}"
            cmake --build "$build_dir" --target llama-server --parallel
            touch "$flags_stamp"
          }

          if [ ! -d "$llama_dir/.git" ]; then
            mkdir -p "''${llama_dir%/*}"
            git clone --depth=1 https://github.com/ggml-org/llama.cpp.git "$llama_dir"
          fi

          git -C "$llama_dir" fetch --depth=1 origin master
          target="$(git -C "$llama_dir" rev-parse origin/master)"

          if [ "$(git -C "$llama_dir" rev-parse HEAD)" != "$target" ]; then
            git -C "$llama_dir" reset --hard "$target"
            build_llama
          elif [ ! -x "$server" ] || [ ! -e "$flags_stamp" ]; then
            build_llama
          fi

          args=(
          ${shellArrayItems serverArgs}
          )

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
            default = 32768;
          };
          parallel = mkOption {
            type = types.ints.positive;
            default = 1;
          };
          mtpDraftTokens = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
          };
        };
      };

      config.home.packages = [ llama ];
    };
}
