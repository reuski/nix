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
            repo = "unsloth/gemma-4-31B-it-GGUF";
            file = "gemma-4-31B-it-UD-Q6_K_XL.gguf";
            mmproj = "mmproj-F16.gguf";
          };
          params.context = localContext;
          extraArgs = [
            "--temp"
            "1.0"
            "--top-p"
            "0.95"
            "--top-k"
            "64"
            "--min-p"
            "0"
            "--spec-type"
            "draft-mtp"
            "--spec-draft-n-max"
            "2"
            "--reasoning"
            "on"
          ];
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
