{ ... }:
{
  flake.modules.darwin.apps = {
    homebrew.casks = [
      "firefox@developer-edition"
      "localsend"
      "signal"
    ];
  };
}
