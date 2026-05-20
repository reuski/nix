{ config, ... }:
{
  home-manager.users.${config.profile.username} =
    { lib, ... }:
    {
      home.activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        /usr/bin/osascript -e 'tell app "Finder" to set desktop picture to POSIX file "${./wallpaper.png}"' &>/dev/null || true
      '';
    };
}
