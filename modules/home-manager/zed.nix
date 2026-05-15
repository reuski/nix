{ ... }:
{
  flake.modules.homeManager.zed = {
    programs.zed-editor = {
      enable = true;
      package = null;

      userSettings = {
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

        project_panel = {
          dock = "right";
          button = false;
        };
        collaboration_panel = {
          dock = "right";
          button = false;
        };
        outline_panel = {
          dock = "right";
          button = false;
        };
        git_panel = {
          dock = "right";
          button = false;
        };
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
          default_profile = "write";
        };

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

        telemetry = {
          diagnostics = false;
          metrics = false;
        };
      };
    };
  };
}
