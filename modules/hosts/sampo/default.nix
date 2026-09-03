{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
  localContext = 131072;
in
{
  configurations.nixos.sampo.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      protonVariants = {
        CachyOS = pkgs.proton-cachyos;
        GE = pkgs.proton-ge-bin;
        CachyOS-LinUwUx = pkgs.proton-cachyos-linuwux;
      };
    in
    {
      programs.steam.extraCompatPackages = builtins.attrValues protonVariants;
      environment.systemPackages = [ pkgs.umu-launcher ];

      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        (import ./_hardware.nix { inherit inputs; })
        ./_network.nix
        nixos.desktop
        nixos.gaming
        ./_audio.nix
        ./_desktop.nix
      ];

      home-manager.users.${config.profile.username} = {
        imports = [
          homeManager.dev
          homeManager.llama
        ];

        xdg.dataFile = lib.mapAttrs' (
          name: package:
          lib.nameValuePair "Steam/compatibilitytools.d/Nix-Proton-${name}" {
            source = package.steamcompattool;
          }
        ) protonVariants;

        llama = {
          build.cudaArchitectures = "86";
          model = {
            repo = "huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF";
            file = "Huihui-Qwen3.8-27B-abliterated-UD-Q4_K_XL.gguf";
            mmproj = "mmproj-model-bf16.gguf";
          };
          params = {
            context = localContext;
            cacheType = "q8_0";
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
