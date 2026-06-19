{ ... }:
{
  flake.modules.homeManager.llama =
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv) isDarwin;
      cudatoolkit = pkgs.cudaPackages.cudatoolkit;

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

      cudaEnv = lib.optionalString (!isDarwin) ''
        export CUDACXX="${cudatoolkit}/bin/nvcc"
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:${lib.makeLibraryPath [ cudatoolkit ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      '';

      llama = pkgs.writeShellApplication {
        name = "llama-server";
        runtimeInputs =
          with pkgs;
          [
            cmake
            git
          ]
          ++ lib.optionals (!isDarwin) [
            gcc
            cudatoolkit
          ];
        text = ''
          ${cudaEnv}
          llama_dir="$HOME/.local/src/llama.cpp"
          server="$llama_dir/build/bin/llama-server"

          build_llama() {
            cmake -S "$llama_dir" -B "$llama_dir/build" \
              -DBUILD_SHARED_LIBS=OFF \
              -DLLAMA_BUILD_TESTS=OFF \
              -DLLAMA_BUILD_EXAMPLES=OFF \
              -DCMAKE_BUILD_TYPE=Release \
              ${backendFlags}
            cmake --build "$llama_dir/build" --config Release \
              -j "$(nproc 2>/dev/null || /usr/sbin/sysctl -n hw.logicalcpu)" --target llama-server
          }

          if [ ! -d "$llama_dir/.git" ]; then
            mkdir -p "''${llama_dir%/*}"
            git clone https://github.com/ggml-org/llama.cpp.git "$llama_dir"
          fi

          git -C "$llama_dir" fetch --prune origin master:refs/remotes/origin/master

          if [ "$(git -C "$llama_dir" rev-parse HEAD)" != "$(git -C "$llama_dir" rev-parse origin/master)" ]; then
            git -C "$llama_dir" merge --ff-only origin/master
            git -C "$llama_dir" submodule update --init --recursive
            build_llama
          elif [ ! -x "$server" ]; then
            git -C "$llama_dir" submodule update --init --recursive
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
