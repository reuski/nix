{ inputs, ... }:
{
  flake.modules.darwin.secrets =
    { config, ... }:
    {
      home-manager.users.${config.profile.username} = {
        imports = [ inputs.sops-nix.homeManagerModules.sops ];

        sops = {
          defaultSopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
          age.keyFile = "${config.profile.homeDirectory}/Library/Application Support/sops/age/keys.txt";
        };
      };
    };
}
