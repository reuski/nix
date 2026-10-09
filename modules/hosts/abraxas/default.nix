{ config, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
  localContext = 65536;
in
{
  configurations.darwin.abraxas.module =
    { config, ... }:
    {
      imports = [
        darwin.mac
        ./_colima.nix
        ./_desktop.nix
        ./_vanta.nix
      ];

      networking.hostName = "abraxas";
      networking.computerName = "abraxas";
      networking.localHostName = "abraxas";

      nixpkgs.hostPlatform = "aarch64-darwin";

      profile.email = "sami@valohai.com";

      home-manager.users.${config.profile.username} = {
        imports = [
          homeManager.dev
          homeManager.llama
        ];

        llama.models = {
          local = {
            hf-repo = "unsloth/gemma-4-31B-it-GGUF";
            hf-file = "gemma-4-31B-it-UD-Q6_K_XL.gguf";
            mmproj-url = "https://huggingface.co/unsloth/gemma-4-31B-it-GGUF/resolve/main/mmproj-F16.gguf";
            ctx-size = localContext;
            jinja = true;
            reasoning-format = "deepseek";
            reasoning-budget = 8192;
            context-shift = false;
            cache-ram = 0;
            cache-idle-slots = false;
            temp = "1.0";
            top-p = "0.95";
            top-k = 64;
            min-p = "0";
            spec-type = "draft-mtp";
            spec-draft-n-max = 2;
            reasoning = "on";
          };
          clef = {
            hf = "ggml-org/Clef-Flash-GGUF:Q8_0";
            no-mmproj = true;
            ctx-size = 8192;
            batch-size = 8192;
            ubatch-size = 8192;
          };
        };

        pi.localModel = {
          enable = true;
          contextWindow = localContext;
          vision = true;
        };
      };

      system.stateVersion = 6;
    };
}
