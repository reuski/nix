{ config, ... }:
let
  inherit (config.flake.modules) generic;
in
{
  flake.modules.homeManager.vim =
    { config, pkgs, ... }:
    {
      imports = [ generic.editor ];

      programs.vim = {
        enable = true;
        plugins = [ pkgs.vimPlugins.gruvbox ];
        extraConfig = config.editor.vimConfig;
      };

      home.sessionVariables = {
        EDITOR = "vim";
        VISUAL = "vim";
      };
    };
}
