{ ... }:
{
  flake.modules.darwin.homebrew = {
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        upgrade = true;
        cleanup = "uninstall";
      };
      taps = [ "imputnet/helium" ];
      brews = [
        "postgresql@18"
        "redis"
      ];
      casks = [
        "cleanshot"
        "ghostty"
        "helium"
        "raycast"
        "tableplus"
        "zed"
      ];
    };
  };
}
