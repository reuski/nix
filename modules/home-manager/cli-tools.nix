{ ... }:
{
  flake.modules.homeManager.cliTools = {
    programs.fd.enable = true;
    programs.jq.enable = true;
    programs.ripgrep.enable = true;
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
