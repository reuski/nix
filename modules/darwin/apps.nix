{ ... }:
{
  flake.modules.darwin.apps =
    { config, pkgs, ... }:
    {
      homebrew.casks = [
        "ghostty"
        "zed"
        "helium-browser"
        "firefox@developer-edition"
        "macshot"
        "tablepro"
      ];

      home-manager.users.${config.profile.username}.home.packages = with pkgs; [
        localsend
      ];
    };
}
