{ config, ... }:
let
  inherit (config.flake.modules) generic homeManager nixos;
in
{
  flake.modules.nixos.stackHiisi =
    { config, ... }:
    {
      imports = [
        generic.profile
        nixos.nixpkgs
        nixos.boot
        nixos.networking
        nixos.users
        nixos.locale
        nixos.audio
        nixos.graphics
        nixos.power
        nixos.niri
        nixos.nix
        nixos.fingerprint
      ];

      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.reuski ];
        profile = config.profile;
      };
    };
}
