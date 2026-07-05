{ ... }:
{
  flake.modules.darwin.apps =
    { config, pkgs, ... }:
    {
      homebrew.casks = [
        "macshot"
        "firefox@developer-edition"
        "ghostty@tip"
        "helium-browser"
        "tableplus"
        "zed"
      ];

      home-manager.users.${config.profile.username}.home.packages = with pkgs; [
        localsend
      ];
    };
}
