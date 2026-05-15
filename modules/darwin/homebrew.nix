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
      casks = [
        "ghostty"
        "helium"
      ];
    };
  };
}
