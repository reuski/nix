{ ... }:
{
  flake.modules.nixos.github =
    {
      config,
      ...
    }:
    let
      keyFile = config.sops.secrets."ssh/github-private-key".path;
    in
    {
      # Private-repo access for flake inputs: add the public half of
      # ssh/github-private-key as a read-only deploy key on each private repo,
      # then pin it as git+ssh://git@github.com/<owner>/<repo>.git?ref=<branch>.
      # Importing this module opts the host in; carry the key in its sops file.
      sops.secrets."ssh/github-private-key" = { };

      programs.ssh = {
        knownHosts.github = {
          hostNames = [ "github.com" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
        extraConfig = ''
          Host github.com
            IdentitiesOnly yes
            IdentityFile ${keyFile}
        '';
      };
    };
}
