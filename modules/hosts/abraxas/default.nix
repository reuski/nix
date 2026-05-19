{ config, ... }:
let
  inherit (config.flake.modules) darwin;
in
{
  configurations.darwin.abraxas.module =
    { config, ... }:
    {
      imports = [ darwin.stackMac ];

      networking.hostName = "abraxas";
      networking.computerName = "abraxas";
      networking.localHostName = "abraxas";

      nixpkgs.hostPlatform = "aarch64-darwin";

      system.stateVersion = 6;

      home-manager.users.${config.profile.username} =
        { lib, ... }:
        {
          sops.secrets.env = { };

          home.activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            /usr/bin/osascript -e 'tell app "Finder" to set desktop picture to POSIX file "${../../profile/wallpaper-abraxas.png}"' &>/dev/null || true
          '';
        };
    };
}
