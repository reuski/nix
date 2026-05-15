{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager darwin;
in
{
  flake.modules.darwin.stackMacbook =
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
        imports = [ homeManager.reuskiMac ];
        profile = config.profile;
      };
    };
}
