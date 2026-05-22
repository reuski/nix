{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.darwin.development =
    { config, ... }:
    {
      homebrew.casks = [
        "tableplus"
        "zed"
      ];

      home-manager.users.${config.profile.username}.imports = [ homeManager.development ];
    };
}
