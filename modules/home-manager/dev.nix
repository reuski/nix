{ ... }:
{
  flake.modules.homeManager.dev =
    { lib, pkgs, ... }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      biomeStack = [
        "biome"
        "vtsls"
        "tailwindcss-language-server"
      ];
      biomeFormatter.language_server.name = "biome";
      biomeLanguage = {
        language_servers = biomeStack;
        formatter = biomeFormatter;
      };
      rightDock = {
        dock = "right";
        button = false;
      };
    in
    {
      home.packages = with pkgs; [
        delve
        gh
        go
        golangci-lint
        govulncheck
        python314
        uv
        zig
      ];

      programs.bun = {
        enable = true;
        enableGitIntegration = true;
      };

      programs.zed-editor = {
        enable = true;
        package = if isDarwin then null else pkgs.zed-editor;

        extensions = [
          "0x96f"
          "bearded-icon-theme"
          "biome"
          "html"
          "svelte"
          "tailwindcss"
          "zig"
        ];

        userSettings = {
          agent_servers.pi = {
            type = "custom";
            command = lib.getExe pkgs.pi-acp;
          };

          theme = "0x96f Theme";
          icon_theme = "Bearded Icon Theme";
          ui_font_size = 16;
          buffer_font_family = "Hack";
          buffer_font_size = 16;
          tab_size = 2;
          autosave = "on_focus_change";
          cli_default_open_behavior = "existing_window";
          remove_trailing_whitespace_on_save = true;
          ensure_final_newline_on_save = true;

          project_panel = rightDock;
          collaboration_panel = rightDock;
          outline_panel = rightDock;
          git_panel = rightDock;
          terminal.button = false;
          toolbar = {
            breadcrumbs = false;
            quick_actions = false;
          };
          tab_bar.show_nav_history_buttons = false;
          gutter = {
            runnables = false;
            breakpoints = false;
            folds = false;
          };

          show_whitespaces = "selection";
          soft_wrap = "editor_width";
          inlay_hints.enabled = false;
          diagnostics.include_warnings = false;

          agent = {
            dock = "left";
            tool_permissions.default = "allow";
            notify_when_agent_waiting = "never";
            enable_feedback = false;
          };

          telemetry = {
            diagnostics = false;
            metrics = false;
          };

          lsp = {
            biome.settings.require_config_file = true;
            gopls.settings = {
              gofumpt = true;
              staticcheck = true;
              analyses = {
                nilness = true;
                shadow = true;
                unusedparams = true;
                unusedwrite = true;
              };
            };
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
            zls.settings = {
              enable_build_on_save = true;
              warn_style = true;
            };
          };

          languages = {
            JavaScript = biomeLanguage;
            JSX = biomeLanguage;
            TypeScript = biomeLanguage;
            TSX = biomeLanguage;
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
            Go = {
              tab_size = 4;
              language_servers = [ "gopls" ];
              formatter.language_server.name = "gopls";
            };
            Zig = {
              tab_size = 4;
              language_servers = [ "zls" ];
              formatter.language_server.name = "zls";
            };
          };
        };
      };
    };
}
