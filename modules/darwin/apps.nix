{ ... }:
{
  flake.modules.darwin.apps =
    { config, pkgs, ... }:
    {
      homebrew.casks = [
        "cleanshot"
        "firefox@developer-edition"
        "ghostty"
        "helium-browser"
        "raycast"
        "tableplus"
        "zed"
      ];

      home-manager.users.${config.profile.username}.home.packages = with pkgs; [
        localsend
      ];
    };
}
