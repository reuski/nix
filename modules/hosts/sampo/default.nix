{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.sampo.module =
    { config, pkgs, ... }:
    let
      protonGeRoot = pkgs.linkFarm "proton-ge-root" [
        {
          name = "share/proton-ge";
          path = pkgs.proton-ge-bin.steamcompattool;
        }
      ];
    in
    {
      programs.steam.extraCompatPackages = [ pkgs.proton-cachyos ];
      environment.systemPackages = [
        protonGeRoot
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
