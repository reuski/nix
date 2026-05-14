{ ... }:
{
  flake.modules.homeManager.helix = {
    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "gruvbox";
        editor = {
          line-number = "relative";
          bufferline = "multiple";
          cursorline = true;
          color-modes = true;
          auto-save = true;
          completion-trigger-len = 1;
          true-color = true;
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          indent-guides = {
            render = true;
            character = "╎";
          };
          lsp.display-inlay-hints = true;
          soft-wrap.enable = true;
        };
        keys.normal.space = {
          space = "file_picker";
          w = ":w";
          q = ":q";
        };
      };
    };
  };
}
