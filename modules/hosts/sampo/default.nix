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
      protonRoots = pkgs.linkFarm "proton-roots" (
        lib.mapAttrsToList (name: package: {
          name = "share/proton-${lib.toLower name}";
          path = package.steamcompattool;
        }) protonVariants
      );
    in
    {
      programs.steam.extraCompatPackages = builtins.attrValues protonVariants;
      environment.systemPackages = [
        protonRoots
        pkgs.umu-launcher
      ];

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

        xdg.configFile = lib.mapAttrs' (
          name: package:
          lib.nameValuePair "heroic/tools/proton/Nix-Proton-${name}" {
            source = package.steamcompattool;
          }
        ) protonVariants;

        llama = {
          model = {
            repo = "OBLITERATUS/Qwen3.8-27B-OBLITERATED";
            file = "Qwen3.8-27B-OBLITERATED-Q4_K_M.gguf";
            chatTemplate = "https://huggingface.co/Qwen/Qwen3.8-27B/raw/main/chat_template.jinja";
          };
          params = {
            context = localContext;
            cacheType = "q8_0";
          };
        };

        pi.localModel = {
          enable = true;
          contextWindow = localContext;
        };
      };

      system.stateVersion = "26.11";
    };
}
