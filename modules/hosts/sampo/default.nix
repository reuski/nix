{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
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
            repo = "0bserverx/Qwen3.8-27B-Heretic-Abliterated-Uncensored-GGUF";
            file = "RVN-Q4_K_M-mtp.gguf";
          };
          params = {
            flashAttention = "on";
            mtpDraftTokens = 2;
          };
        };
      };

      system.stateVersion = "26.11";
    };
}
