{ inputs, ... }:
{
  flake.modules.darwin.secrets =
    { config, ... }:
    {
      home-manager.users.${config.profile.username} =
        { pkgs, ... }:
        {
          imports = [ inputs.sops-nix.homeManagerModules.sops ];

          home.packages = with pkgs; [
            age
            sops
            ssh-to-age
          ];

          sops = {
            defaultSopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
            age.keyFile = "${config.profile.homeDirectory}/Library/Application Support/sops/age/keys.txt";
          };
        };
    };
}
