{ ... }:
{
  flake.modules.homeManager.devenv = {
    programs.devenv = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableNushellIntegration = false;
      enableZshIntegration = false;
    };
  };
}
