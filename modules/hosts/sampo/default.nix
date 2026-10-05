{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
  localContext = 131072;
in
{
  configurations.nixos.sampo.module =
    { config, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        (import ./_hardware.nix { inherit inputs; })
        ./_network.nix
        nixos.desktop
        nixos.gaming
        ./_gaming.nix
        ./_audio.nix
        ./_desktop.nix
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
            hf-repo = "unsloth/gemma-4-26B-A4B-it-GGUF";
            hf-file = "gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf";
            mmproj-url = "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/resolve/main/mmproj-BF16.gguf";
            ctx-size = localContext;
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

        pi.localModel = {
          enable = true;
          contextWindow = localContext;
          vision = true;
        };
      };

      system.stateVersion = "26.11";
    };
}
