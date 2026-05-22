{ ... }:
{
  flake.modules.homeManager.typescript = {
    programs.zed-editor = {
      extensions = [
        "biome"
        "html"
        "svelte"
        "tailwindcss"
      ];

      userSettings = {
        lsp = {
          biome.settings.require_config_file = true;
          tailwindcss-language-server.settings.classAttributes = [
            "class"
            "className"
            "ngClass"
            "class:list"
            ".*Class.*"
            ".*Classes.*"
            ".*ClassNames.*"
            ".*Styles.*"
            ".*Style.*"
          ];
          vtsls.settings = {
            javascript = {
              preferences.includePackageJsonAutoImports = "auto";
              suggest.completeFunctionCalls = true;
              updateImportsOnFileMove.enabled = "always";
            };
            typescript = {
              preferences = {
                includePackageJsonAutoImports = "auto";
                preferTypeOnlyAutoImports = true;
              };
              suggest.completeFunctionCalls = true;
              updateImportsOnFileMove.enabled = "always";
            };
          };
        };

        languages =
          let
            biomeStack = [
              "biome"
              "vtsls"
              "tailwindcss-language-server"
            ];
            biomeFormatter.language_server.name = "biome";
          in
          {
            JavaScript = {
              language_servers = biomeStack;
              formatter = biomeFormatter;
            };
            JSX = {
              language_servers = biomeStack;
              formatter = biomeFormatter;
            };
            TypeScript = {
              language_servers = biomeStack;
              formatter = biomeFormatter;
            };
            TSX = {
              language_servers = biomeStack;
              formatter = biomeFormatter;
            };
            Svelte = {
              language_servers = [
                "svelte-language-server"
                "tailwindcss-language-server"
              ];
              formatter.language_server.name = "svelte-language-server";
            };
            HTML.language_servers = [
              "html"
              "tailwindcss-language-server"
            ];
            CSS.language_servers = [
              "css-variables-lsp"
              "css"
              "tailwindcss-language-server"
            ];
          };
      };
    };
  };
}
