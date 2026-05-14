{ ... }:
{
  flake.modules.homeManager.fzf =
    { config, ... }:
    let
      gruvbox = config.profile.colors.gruvbox;
    in
    {
      programs.fzf = {
        enable = true;
        enableFishIntegration = true;
        colors = {
          bg = gruvbox.bg0;
          "bg+" = gruvbox.bg1;
          fg = gruvbox.fg1;
          "fg+" = gruvbox.fg1;
          header = gruvbox.gray;
          hl = gruvbox.yellow;
          "hl+" = gruvbox.yellow;
          info = gruvbox.blue;
          marker = gruvbox.orange;
          pointer = gruvbox.orange;
          prompt = gruvbox.green;
          spinner = gruvbox.yellow;
          border = gruvbox.bg2;
        };
      };
    };
}
