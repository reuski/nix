{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager darwin;
in
{
  flake.modules.darwin.stackMac =
    { config, pkgs, ... }:
    {
      imports = [
        generic.profile
        darwin.nixpkgs
        darwin.nix
        darwin.users
        darwin.system
        darwin.fonts
        darwin.homebrew
        darwin.secrets
      ];

      home-manager.users.${config.profile.username} = {
        home.packages = with pkgs; [
          age
          sops
          ssh-to-age
        ];
        imports = [
          homeManager.mac
          homeManager.llamaServer
        ];
        profile = config.profile;
      };
    };
}
