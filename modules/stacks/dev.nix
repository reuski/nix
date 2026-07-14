{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.homeManager.dev = {
    imports = [
      homeManager.direnv
      homeManager.devenv
      homeManager.gh
      homeManager.pi
      homeManager.zed-editor
    ];
  };
}
