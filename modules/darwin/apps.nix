{ ... }:
{
  flake.modules.darwin.apps = {
    services.tailscale.enable = true;

    homebrew.casks = [
      "firefox@developer-edition"
      "localsend"
      "signal"
    ];
  };
}
