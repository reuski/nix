{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.sampo.module =
    { config, pkgs, ... }:
    let
      protonVariants = [
        {
          id = "cachyos";
          name = "CachyOS";
          package = pkgs.proton-cachyos;
        }
        {
          id = "ge";
          name = "GE";
          package = pkgs.proton-ge-bin;
        }
        {
          id = "cachyos-linuwux";
          name = "CachyOS-LinUwUx";
          package = pkgs.proton-cachyos-linuwux;
        }
      ];
      protonRoots = pkgs.linkFarm "proton-roots" (
        map (variant: {
          name = "share/proton-${variant.id}";
          path = variant.package.steamcompattool;
        }) protonVariants
      );
    in
    {
      programs.steam.extraCompatPackages = map (variant: variant.package) protonVariants;
      environment.systemPackages = [
        protonRoots
        pkgs.umu-launcher
      ];

      nix.settings = {
        extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
        extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
      };

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

        xdg.configFile = builtins.listToAttrs (
          map (variant: {
            name = "heroic/tools/proton/Nix-Proton-${variant.name}";
            value.source = variant.package.steamcompattool;
          }) protonVariants
        );

        llama = {
          model = {
            repo = "unsloth/Qwen3.6-27B-MTP-GGUF";
            file = "Qwen3.6-27B-UD-Q4_K_XL.gguf";
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
