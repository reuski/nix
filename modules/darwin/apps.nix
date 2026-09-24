{ ... }:
{
  flake.modules.darwin.apps =
    { ... }:
    {
      homebrew.casks = [
        "ghostty"
        "zed"
        "helium-browser"
        "firefox@developer-edition"
        "macshot"
        "tablepro"
      ];
    };
}
