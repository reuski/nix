{ ... }:
{
  flake.modules.homeManager.go = {
    programs.zed-editor.userSettings = {
      lsp.gopls.settings = {
        gofumpt = true;
        staticcheck = true;
        analyses = {
          nilness = true;
          shadow = true;
          unusedparams = true;
          unusedwrite = true;
        };
      };

      languages.Go = {
        tab_size = 4;
        language_servers = [ "gopls" ];
        formatter.language_server.name = "gopls";
      };
    };
  };
}
