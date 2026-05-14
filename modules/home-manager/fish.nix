{ ... }:
{
  flake.modules.homeManager.fish =
    { config, lib, pkgs, ... }:
    let
      gruvbox = config.profile.colors.gruvbox;
      fishHex = color: builtins.substring 1 6 color;
    in
    {
      programs.fish = {
        enable = true;
        plugins = [
          {
            name = "pure";
            src = pkgs.fishPlugins.pure.src;
          }
        ];
        interactiveShellInit = ''
          set -g fish_greeting
          set -g pure_check_for_new_release false
          set -g pure_begin_prompt_with_current_directory true
          set -g pure_threshold_command_duration 5

          set -g pure_color_primary ${fishHex gruvbox.yellow}
          set -g pure_color_success ${fishHex gruvbox.green}
          set -g pure_color_info ${fishHex gruvbox.blue}
          set -g pure_color_mute ${fishHex gruvbox.gray}
          set -g pure_color_danger ${fishHex gruvbox.red}

          set -g fish_color_command ${fishHex gruvbox.green}
          set -g fish_color_keyword ${fishHex gruvbox.red}
          set -g fish_color_quote ${fishHex gruvbox.green}
          set -g fish_color_error ${fishHex gruvbox.red}
          set -g fish_color_param ${fishHex gruvbox.fg1}
          set -g fish_color_comment ${fishHex gruvbox.gray}
          set -g fish_color_autosuggestion ${fishHex gruvbox.gray}
          set -g fish_color_selection --background=${fishHex gruvbox.bg2}
          set -g fish_pager_color_prefix ${fishHex gruvbox.yellow} --bold
          set -g fish_pager_color_description ${fishHex gruvbox.gray}

          if status is-interactive; and not set -q ZELLIJ; and test -z "$ZELLIJ_AUTO_ATTACHED"
            set -gx ZELLIJ_AUTO_ATTACHED 1
            ${lib.getExe pkgs.zellij} attach main --create
          end
        '';
        shellAbbrs = {
          g = "git";
          vi = "hx";
          dl = "cd ~/Downloads";
          p = "cd ~/Projects";
        };
      };
    };
}
