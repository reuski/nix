{ ... }:
{
  flake.modules.darwin.apps = {
    homebrew.casks = [
      "firefox@developer-edition"
      "signal"
      "localsend"
    ];
  };
}
