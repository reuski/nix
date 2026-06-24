{ ... }:
{
  flake.modules.homeManager.ssh =
    { config, pkgs, ... }:
    let
      identityFile =
        if pkgs.stdenv.isLinux then
          "/run/secrets/ssh/id_ed25519"
        else
          "${config.home.homeDirectory}/.config/sops-nix/secrets/ssh/id_ed25519";
    in
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks."*" = {
          inherit identityFile;
          identitiesOnly = true;
          addKeysToAgent = "yes";
        };
      };

      home.file.".ssh/id_ed25519.pub".text = "${config.profile.sshPublicKey}\n";
    };
}
