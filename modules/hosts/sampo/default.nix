{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.sampo.module =
    { config, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        ./_hardware.nix
        ./_network.nix
        ./_nfs.nix
        nixos.desktop
        nixos.gaming
        ./_gaming.nix
        ./_audio.nix
        ./_desktop.nix
        (import ./_comfyui.nix { inherit inputs; })
      ];

      home-manager.users.${config.profile.username} = {
        imports = [
          homeManager.dev
          homeManager.llama
        ];

        llama = {
          build.cudaArchitectures = "86";
          ui = true;
          models.local = {
            dedup-cache-models = true;
            hf-repo = "unsloth/gemma-4-26B-A4B-it-GGUF";
            hf-file = "gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf";
            mmproj-url = "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/resolve/main/mmproj-BF16.gguf";
            ctx-size = 131072;
            gpu-layers = "auto";
            fit = "on";
            cache-type-k = "q8_0";
            cache-type-v = "q8_0";
            jinja = true;
            reasoning = "off";
            context-shift = false;
            cache-ram = 0;
            cache-idle-slots = false;
            temp = "1.0";
            top-p = "0.95";
            top-k = 64;
            min-p = "0";
            spec-type = "draft-mtp";
            spec-draft-n-max = 2;
          };
        };
      };

      system.stateVersion = "26.11";
    };
}
