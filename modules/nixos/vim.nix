{ config, ... }:
let
  inherit (config.flake.modules) generic;
in
{
  flake.modules.nixos.vim =
    { config, pkgs, ... }:
    let
      vim = pkgs.vim-full.customize {
        name = "vim";
        vimrcConfig = {
          packages.gruvbox.start = [ pkgs.vimPlugins.gruvbox ];
          customRC = config.editor.vimConfig;
        };
      };
    in
    {
      imports = [ generic.editor ];

      environment.systemPackages = [ vim ];
      environment.variables = {
        EDITOR = "vim";
        VISUAL = "vim";
      };
    };
}
