{ inputs, ... }:
{
  flake.modules.darwin.homebrew =
    { config, ... }:
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

      nix-homebrew = {
        enable = true;
        user = config.profile.username;
      };

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
          "localsend"
          "raycast"
          "tableplus"
          "tailscale"
          "zed"
        ];
      };
    };
}
