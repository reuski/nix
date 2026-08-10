{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.sampo.module =
    { config, pkgs, ... }:
    let
      protonRoots = pkgs.linkFarm "proton-roots" [
        {
          name = "share/proton-cachyos";
          path = pkgs.proton-cachyos.steamcompattool;
        }
        {
          name = "share/proton-ge";
          path = pkgs.proton-ge-bin.steamcompattool;
        }
      ];
    in
    {
      programs.steam.extraCompatPackages = [ pkgs.proton-cachyos ];
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

        xdg.configFile = {
          "heroic/tools/proton/Nix-Proton-CachyOS".source = pkgs.proton-cachyos.steamcompattool;
          "heroic/tools/proton/Nix-Proton-GE".source = pkgs.proton-ge-bin.steamcompattool;
        };

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
