{ ... }:
{
  flake.modules.homeManager.delta = {
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
        syntax-theme = "gruvbox-dark";
      };
    };
  };
}
