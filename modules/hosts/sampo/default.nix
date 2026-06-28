{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.sampo.module =
    { config, ... }:
    {
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

      sops.secrets.env = {
        sopsFile = ../../../secrets/env.yaml;
        owner = config.profile.username;
      };

      sops.secrets."ssh/id_ed25519" = {
        sopsFile = ../../../secrets/ssh.yaml;
        owner = config.profile.username;
        mode = "0400";
      };

      sops.secrets.admin_age_key = {
        sopsFile = ../../../secrets/admin.yaml;
        owner = config.profile.username;
        mode = "0400";
      };

      home-manager.users.${config.profile.username}.imports = [
        homeManager.dev
        homeManager.llama
        homeManager.secrets
        homeManager.ssh
      ];

      system.stateVersion = config.system.nixos.release;
    };
}
