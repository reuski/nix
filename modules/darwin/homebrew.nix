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
        greedyCasks = true;
        onActivation = {
          autoUpdate = true;
          upgrade = true;
          cleanup = "uninstall";
        };
      };
    };
}
