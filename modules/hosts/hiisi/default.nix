{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
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
        ./_hardware.nix
        nixos.wayland
        ./_desktop.nix
      ];

      sops.secrets.env = {
        owner = config.profile.username;
      };

      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.dev ];
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
