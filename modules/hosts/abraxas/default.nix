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

        llama = {
          model = {
            repo = "unsloth/Qwen3.8-27B-GGUF";
            file = "Qwen3.8-27B-UD-Q8_K_XL.gguf";
            mmproj = "mmproj-F16.gguf";
          };
          params.context = localContext;
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
