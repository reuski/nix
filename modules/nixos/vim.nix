{ ... }:
{
  flake.modules.nixos.vim =
    { config, pkgs, ... }:
    let
      vim = pkgs.vim_configurable.customize {
        name = "vim";
        vimrcConfig = {
          packages.gruvbox.start = [ pkgs.vimPlugins.gruvbox ];
          customRC = config.profile.editor.vimConfig;
        };
      };
    in
    {
      environment.systemPackages = [ vim ];
      environment.variables = {
        EDITOR = "vim";
        VISUAL = "vim";
      };
    };
}
