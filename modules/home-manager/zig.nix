{ ... }:
{
  flake.modules.homeManager.zig = {
    programs.zed-editor = {
      extensions = [ "zig" ];

      userSettings = {
        lsp.zls.settings = {
          enable_build_on_save = true;
          warn_style = true;
        };

        languages.Zig = {
          tab_size = 4;
          language_servers = [ "zls" ];
          formatter.language_server.name = "zls";
        };
      };
    };
  };
}
