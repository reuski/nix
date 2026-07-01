{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.workstation =
    { config, ... }:
    {
      hardware.graphics.enable = true;

      programs.localsend = {
        enable = true;
        openFirewall = true;
      };

      sops.secrets.env = {
        sopsFile = ../../secrets/env.yaml;
        owner = config.profile.username;
      };

      sops.secrets."ssh/id_ed25519" = {
        sopsFile = ../../secrets/ssh.yaml;
        owner = config.profile.username;
        mode = "0400";
      };

      sops.secrets.admin_age_key = {
        sopsFile = ../../secrets/admin.yaml;
        owner = config.profile.username;
        mode = "0400";
      };

      home-manager.users.${config.profile.username}.imports = [
        homeManager.secrets
        homeManager.ssh
      ];
    };
}
