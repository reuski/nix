{ inputs, ... }:
{
  flake.modules.nixos.secrets =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops = {
        defaultSopsFile =
          let
            hostFile = ../../secrets + "/${config.networking.hostName}.yaml";
          in
          if builtins.pathExists hostFile then hostFile else ../../secrets/env.yaml;
        age = {
          sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          keyFile = null;
          generateKey = false;
        };
        gnupg.sshKeyPaths = [ ];
      };
    };
}
