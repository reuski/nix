{ config, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
in
{
  configurations.darwin.abraxas.module =
    { config, ... }:
    {
      imports = [
        darwin.mac
        ./_colima.nix
        ./_desktop.nix
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

        llama.model = {
          repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
          file = "Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf";
          mmproj = "mmproj-F16.gguf";
        };
      };

      system.stateVersion = 6;
    };
}
