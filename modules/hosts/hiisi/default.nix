{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.hiisi.module =
    { config, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
        ./_hardware.nix
        nixos.laptop
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
        homeManager.secrets
        homeManager.ssh
      ];

      system.stateVersion = config.system.nixos.release;
    };
}
