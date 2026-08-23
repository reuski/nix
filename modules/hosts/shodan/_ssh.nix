{ lib, ... }:
let
  deployKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7opoZAqwT02nbFtBErutj8nA4aO7KaUORej9b1VanK deploy@reuski.dev";
in
{
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "prohibit-password";
    AllowUsers = lib.mkForce [
      "reuski"
      "root"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [ deployKey ];
}
