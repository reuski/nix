{ inputs, ... }:
{
  flake.modules.nixos.secrets =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops = {
        defaultSopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
        age = {
          sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          keyFile = null;
          generateKey = false;
        };
        gnupg.sshKeyPaths = [ ];
      };
    };
}
