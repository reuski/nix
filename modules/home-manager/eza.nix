{ ... }:
{
  flake.modules.homeManager.eza = {
    programs.eza = {
      enable = true;
      enableFishIntegration = true;
      git = true;
      icons = "auto";
    };
  };
}
