{ ... }:
{
  flake.modules.homeManager.llama =
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv) isDarwin;
      cp = pkgs.cudaPackages;
      toolchain = if isDarwin then pkgs.stdenv.cc else cp.backendStdenv.cc;
      tls = pkgs.openssl;
      cudaInc = lib.concatStringsSep ":" [
        "${lib.getDev cp.cuda_cudart}/include"
        "${lib.getDev cp.cccl}/include"
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

      backendFlags = lib.concatStringsSep " " (
        if isDarwin then
          [
            "-DGGML_METAL=ON"
            "-DGGML_METAL_NDEBUG=ON"
            "-DGGML_METAL_EMBED_LIBRARY=ON"
            "-DGGML_OPENMP=OFF"
          ]
        else
          [
            "-DGGML_CUDA=ON"
            "-DCMAKE_CUDA_ARCHITECTURES=native"
          ]
      );

      buildEnv = ''
        export CMAKE_PREFIX_PATH="${lib.getDev tls}:${lib.getLib tls}''${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
        export LD_LIBRARY_PATH="${runLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export DYLD_LIBRARY_PATH="${runLibPath}''${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
      '';

      cudaEnv = lib.optionalString (!isDarwin) ''
        export CUDACXX="${lib.getExe' cp.cuda_nvcc "nvcc"}"
        export CUDAHOSTCXX="${lib.getExe' cp.backendStdenv.cc "g++"}"
        # split-layout: nvcc's own include lacks cuda_runtime.h/<nv/target>; expose cudart+cccl.
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
            toolchain
            ccache
          ]
          ++ lib.optionals (!isDarwin) [
            cp.cuda_nvcc
            cp.cccl
            cp.cuda_cudart
            cp.libcublas
          ];
        text = ''
          ${buildEnv}
          ${cudaEnv}
          llama_dir="$HOME/.local/src/llama.cpp"
          server="$llama_dir/build/bin/llama-server"

          build_llama() {
            cmake -S "$llama_dir" -B "$llama_dir/build" -G Ninja \
              -DBUILD_SHARED_LIBS=OFF \
              -DCMAKE_BUILD_TYPE=Release \
              -DLLAMA_BUILD_TESTS=OFF \
              -DLLAMA_BUILD_EXAMPLES=OFF \
              -DLLAMA_BUILD_APP=OFF \
              -DGGML_BUILD_TESTS=OFF \
              -DGGML_BUILD_EXAMPLES=OFF \
              -DLLAMA_OPENSSL=ON \
              ${backendFlags}
            cmake --build "$llama_dir/build" --target llama-server
          }

          if [ ! -d "$llama_dir/.git" ]; then
            mkdir -p "''${llama_dir%/*}"
            git clone https://github.com/ggml-org/llama.cpp.git "$llama_dir"
          fi

          git -C "$llama_dir" fetch origin

          if [ "$(git -C "$llama_dir" rev-parse HEAD)" != "$(git -C "$llama_dir" rev-parse origin/master)" ]; then
            git -C "$llama_dir" reset --hard origin/master
            build_llama
          elif [ ! -x "$server" ]; then
            build_llama
          fi

          model="''${LLAMA_MODEL:-unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q6_K_XL}"

          args=(
            -hf "$model"
            --host 127.0.0.1
            --port 8080
            -ngl all
            -c 8192
            -fa on
            -np 1
            --no-mmproj
            --spec-type draft-mtp
            --spec-draft-n-max 2
            --temp 0.6
            --top-k 20
            --top-p 0.95
            --min-p 0.0
            --presence-penalty 0.0
            --repeat-penalty 1.0
            --reasoning on
            --reasoning-budget -1
            --jinja
            --no-ui
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
      home.packages = [ llama ];
    };
}
