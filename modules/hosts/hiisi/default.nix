{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.hiisi.module =
    { config, pkgs, ... }:
    let
      ageKeyFile = "${config.profile.homeDirectory}/.config/sops/age/keys.txt";
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
        nixos.thinkpadT480
        ./_hardware.nix
        ./_fingerprint.nix
        nixos.stackWayland
      ];

      sops.secrets.env = {
        owner = config.profile.username;
      };

      home-manager.users.${config.profile.username} = {
        home.file.".config/sops/age/.keep".text = "";
        home.packages = with pkgs; [
          age
          sops
          ssh-to-age
        ];
        home.sessionVariables.SOPS_AGE_KEY_FILE = ageKeyFile;
      };

      site.autoUpgradeFlake = "github:reuski/nix/main";
      system.stateVersion = "25.11";
    };
}
