{ ... }:
{
  flake.modules.homeManager.bun = {
    programs.bun = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
