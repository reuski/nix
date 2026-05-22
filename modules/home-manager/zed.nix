{ ... }:
{
  flake.modules.homeManager.zed =
    { pkgs, ... }:
    let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    in
    {
      programs.zed-editor = {
        enable = true;
        package = if isDarwin then null else pkgs.zed-editor;

        extensions = [
          "0x96f"
          "bearded-icon-theme"
        ];

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

          telemetry = {
            diagnostics = false;
            metrics = false;
          };
        };
      };
    };
}
