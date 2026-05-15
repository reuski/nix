{ ... }:
{
  flake.modules.homeManager.zellij =
    { config, pkgs, ... }:
    let
      gruvbox = config.profile.colors.gruvbox;
      copyCommand = if pkgs.stdenv.hostPlatform.isDarwin then "pbcopy" else "wl-copy";
    in
    {
      xdg.configFile."zellij/config.kdl".text = ''
        theme "gruvbox-dark"
        default_layout "main"
        default_mode "locked"
        simplified_ui true
        pane_frames false
        mouse_mode true
        copy_command "${copyCommand}"
        copy_on_select true
        session_serialization false
        show_startup_tips false
        show_release_notes false

        plugins {
            zjstatus location="file:${pkgs.zjstatus}/share/zellij/plugins/zjstatus.wasm" {
                color_bg     "${gruvbox.bg0}"
                color_fg     "${gruvbox.fg1}"
                color_red    "${gruvbox.red}"
                color_green  "${gruvbox.green}"
                color_blue   "${gruvbox.blue}"
                color_yellow "${gruvbox.yellow}"
                color_gray   "${gruvbox.gray}"

                border_enabled  "true"
                border_char     " "
                border_format   "{char}"
                border_position "top"

                format_left  "#[fg=$gray]{mode}  {tabs}"
                format_right "#[fg=$gray]{datetime}"
                format_space " "

                mode_normal         "#[fg=$green]NORM"
                mode_locked         "#[fg=$red]LOCK"
                mode_tmux           "#[fg=$yellow]TMUX"
                mode_resize         "#[fg=$yellow]RESZ"
                mode_pane           "#[fg=$yellow]PANE"
                mode_tab            "#[fg=$yellow]TABS"
                mode_scroll         "#[fg=$yellow]SCRL"
                mode_enter_search   "#[fg=$yellow]SRCH"
                mode_search         "#[fg=$yellow]SRCH"
                mode_rename_tab     "#[fg=$yellow]RNAM"
                mode_rename_pane    "#[fg=$yellow]RNAM"
                mode_session        "#[fg=$yellow]SESS"
                mode_move           "#[fg=$yellow]MOVE"
                mode_prompt         "#[fg=$blue]PROM"
                mode_default_to_mode "normal"

                tab_normal               "#[fg=$gray]  {index}  "
                tab_active               "#[fg=$fg,bold]  {index}  "
                tab_sync_indicator       "  SYNC "
                tab_fullscreen_indicator "  FULL "
                tab_floating_indicator   "  FLOAT "

                datetime          "#[fg=$gray]{format}"
                datetime_format   "%H:%M"
                datetime_timezone "${config.profile.timeZone}"
            }
        }

        themes {
            gruvbox-dark {
                fg "${gruvbox.fg1}"
                bg "${gruvbox.bg0}"
                black "${gruvbox.black}"
                red "${gruvbox.red}"
                green "${gruvbox.green}"
                yellow "${gruvbox.yellow}"
                blue "${gruvbox.blue}"
                magenta "${gruvbox.purple}"
                cyan "${gruvbox.aqua}"
                white "${gruvbox.white}"
                orange "${gruvbox.orange}"
            }
        }

        keybinds clear-defaults=true {
            locked {
                bind "Alt g" { SwitchToMode "Normal"; }
                bind "Alt n" { NewPane; }
                bind "Alt t" { NewTab; }
                bind "Alt w" { CloseFocus; }
                bind "Alt h" { MoveFocus "Left"; }
                bind "Alt l" { MoveFocus "Right"; }
                bind "Alt j" { MoveFocus "Down"; }
                bind "Alt k" { MoveFocus "Up"; }
                bind "Alt H" { MovePane "Left"; }
                bind "Alt L" { MovePane "Right"; }
                bind "Alt J" { MovePane "Down"; }
                bind "Alt K" { MovePane "Up"; }
                bind "Alt f" { ToggleFloatingPanes; }
            }

            shared_except "locked" {
                bind "Alt g" "Esc" "Enter" { SwitchToMode "Locked"; }
            }
        }
      '';

      xdg.configFile."zellij/layouts/main.kdl".text = ''
        layout {
            default_tab_template {
                children

                pane size=2 borderless=true {
                    plugin location="zjstatus"
                }
            }

            tab {
                pane
            }
        }
      '';
    };
}
