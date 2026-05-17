{ ... }:
{
  flake.modules.homeManager.vim =
    { config, pkgs, ... }:
    {
      programs.vim = {
        enable = true;
        plugins = [ pkgs.vimPlugins.gruvbox ];
        extraConfig = config.profile.editor.vimConfig;
      };

      home.sessionVariables = {
        EDITOR = "vim";
        VISUAL = "vim";
      };
    };
}
