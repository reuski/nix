{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager darwin;
in
{
  flake.modules.darwin.mac =
    { config, ... }:
    {
      imports = [
        generic.profile
        darwin.nixpkgs
        darwin.nix
        darwin.users
        darwin.system
        darwin.fonts
        darwin.apps
        darwin.tailscale
        darwin.homebrew
        darwin.secrets
      ];

      home-manager.users.${config.profile.username} = {
        imports = [
          homeManager.mac
          homeManager.llama
        ];
        profile = config.profile;
      };
    };
}
