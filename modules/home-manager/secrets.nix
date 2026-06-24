{ inputs, ... }:
{
  flake.modules.homeManager.secrets =
    { config, pkgs, ... }:
    let
      bootstrapKeyFile =
        if pkgs.stdenv.isDarwin then
          "${config.home.homeDirectory}/Library/Application Support/sops/age/keys.txt"
        else
          "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      adminKeyFile =
        if pkgs.stdenv.isDarwin then
          "${config.home.homeDirectory}/.config/sops-nix/secrets/admin_age_key"
        else
          "/run/secrets/admin_age_key";
    in
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      home.packages = with pkgs; [
        age
        sops
        ssh-to-age
      ];

      home.file.".config/sops/age/.keep".text = "";
      home.sessionVariables.SOPS_AGE_KEY_FILE = adminKeyFile;

      sops.age.keyFile = bootstrapKeyFile;
    };
}
