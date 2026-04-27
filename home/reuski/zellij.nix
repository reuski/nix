{ pkgs, ... }:
let
  gruvbox = {
    bg = "#282828";
    fg = "#ebdbb2";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    gray = "#928374";
    cyan = "#8ec07c";
    magenta = "#d3869b";
    orange = "#fe8019";
    black = "#1d2021";
    white = "#a89984";
  };
in
{
  xdg.configFile."zellij/config.kdl".text = ''
    theme "gruvbox-dark"
    default_layout "main"
    default_mode "locked"
    mouse_mode true
    copy_command "wl-copy"
    copy_on_select true
    session_serialization true
    show_startup_tips false

    plugins {
      zjstatus location="file:${pkgs.zjstatus}/share/zellij/plugins/zjstatus.wasm" {
        hide_frame_for_single_pane "true"

        color_bg     "${gruvbox.bg}"
        color_fg     "${gruvbox.fg}"
        color_red    "${gruvbox.red}"
        color_green  "${gruvbox.green}"
        color_blue   "${gruvbox.blue}"
        color_yellow "${gruvbox.yellow}"
        color_gray   "${gruvbox.gray}"

        format_left  "#[fg=$color_fg,bold]{mode}  {tabs}"
        format_right "#[fg=$color_gray]{datetime}"
        format_space " "

        mode_normal        "#[fg=$color_green,bold]NORM"
        mode_locked        "#[fg=$color_red,bold]LOCK"
        mode_tmux          "#[fg=$color_yellow,bold]TMUX"
        mode_resize        "#[fg=$color_yellow,bold]RSZE"
        mode_pane          "#[fg=$color_yellow,bold]PANE"
        mode_tab           "#[fg=$color_yellow,bold]TAB"
        mode_scroll        "#[fg=$color_yellow,bold]SCRL"
        mode_enter_search  "#[fg=$color_yellow,bold]SRCH"
        mode_search        "#[fg=$color_yellow,bold]SRCH"
        mode_rename_tab    "#[fg=$color_yellow,bold]RNME"
        mode_rename_pane   "#[fg=$color_yellow,bold]RNME"
        mode_session       "#[fg=$color_yellow,bold]SESS"
        mode_move          "#[fg=$color_yellow,bold]MOVE"
        mode_prompt        "#[fg=$color_blue,bold]PRMT"
        mode_default_to_mode "normal"

        tab_normal               "#[fg=$color_gray] {index} "
        tab_active               "#[fg=$color_fg,bold] {index} "
        tab_sync_indicator       "󰓦 "
        tab_fullscreen_indicator "󰊓 "
        tab_floating_indicator   "󰉈 "

        datetime         "#[fg=$color_gray] {format} "
        datetime_format  "%H:%M"
        datetime_timezone "Europe/Helsinki"
      }
    }

    themes {
      gruvbox-dark {
        fg "${gruvbox.fg}"
        bg "${gruvbox.bg}"
        black "${gruvbox.black}"
        red "${gruvbox.red}"
        green "${gruvbox.green}"
        yellow "${gruvbox.yellow}"
        blue "${gruvbox.blue}"
        magenta "${gruvbox.magenta}"
        cyan "${gruvbox.cyan}"
        white "${gruvbox.white}"
        orange "${gruvbox.orange}"
      }
    }

    keybinds clear-defaults=true {
      locked {
        bind "Alt g" { SwitchToMode "normal"; }
        bind "Alt n" { NewPane; }
        bind "Alt t" { NewTab; }
        bind "Alt w" { CloseFocus; }
        bind "Alt h" { MoveFocus "left"; }
        bind "Alt l" { MoveFocus "right"; }
        bind "Alt j" { MoveFocus "down"; }
        bind "Alt k" { MoveFocus "up"; }
        bind "Alt H" { MovePane "left"; }
        bind "Alt L" { MovePane "right"; }
        bind "Alt J" { MovePane "down"; }
        bind "Alt K" { MovePane "up"; }
        bind "Alt f" { ToggleFloatingPanes; }
      }
      shared_except "locked" {
        bind "Alt g" "Esc" "Enter" { SwitchToMode "locked"; }
      }
    }
  '';

  xdg.configFile."zellij/layouts/main.kdl".text = ''
    layout {
      default_tab_template {
        children
        pane size=1 borderless=true {
          plugin location="zjstatus"
        }
      }
      tab
    }
  '';
}
