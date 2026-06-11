{ inputs, ... }:
{
  flake.modules.homeManager.secrets =
    { config, pkgs, ... }:
    let
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    in
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      home.packages = with pkgs; [
        age
        sops
        ssh-to-age
      ];

      home.file.".config/sops/age/.keep".text = "";
      home.sessionVariables.SOPS_AGE_KEY_FILE = keyFile;

      sops.age.keyFile = keyFile;
    };
}
