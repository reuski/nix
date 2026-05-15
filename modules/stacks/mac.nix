{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager darwin;
in
{
  flake.modules.darwin.stackMac =
    { config, ... }:
    {
      imports = [
        generic.profile
        darwin.nixpkgs
        darwin.nix
        darwin.users
        darwin.system
        darwin.homebrew
      ];

      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.mac ];
        profile = config.profile;
      };
    };
}
