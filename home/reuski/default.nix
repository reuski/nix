{ pkgs, ... }:
let
  gruvbox = {
    bg0 = "#282828";
    bg1 = "#3c3836";
    bg2 = "#504945";
    fg1 = "#ebdbb2";
    gray = "#928374";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    purple = "#d3869b";
    aqua = "#8ec07c";
    orange = "#fe8019";
  };
  fishHex = color: builtins.substring 1 6 color;
  gruvboxDarkGtkTheme = {
    package = pkgs.gruvbox-gtk-theme;
    name = "Gruvbox-Dark";
  };
in
{
  imports = [
    ./xdg.nix
    ./niri.nix
    ./noctalia.nix
    ./vicinae.nix
    ./ghostty.nix
  ];

  home.username = "reuski";
  home.homeDirectory = "/home/reuski";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    helium-browser
    wl-clipboard
    brightnessctl
    playerctl
    grim
    slurp
    imv
  ];

  programs.home-manager.enable = true;
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
    '';
    shellAbbrs = {
      g = "git";
      vi = "vim";
      dl = "cd ~/Downloads";
      p = "cd ~/Projects";
    };
  };
  programs.bat = {
    enable = true;
    config.theme = "gruvbox-dark";
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      syntax-theme = "gruvbox-dark";
    };
  };
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
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    git = true;
    icons = "auto";
  };
  programs.fd.enable = true;
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    colors = {
      bg = gruvbox.bg0;
      "bg+" = gruvbox.bg1;
      fg = gruvbox.fg1;
      "fg+" = gruvbox.fg1;
      header = gruvbox.gray;
      hl = gruvbox.yellow;
      "hl+" = gruvbox.yellow;
      info = gruvbox.blue;
      marker = gruvbox.orange;
      pointer = gruvbox.orange;
      prompt = gruvbox.green;
      spinner = gruvbox.yellow;
      border = gruvbox.bg2;
    };
  };
  programs.git = {
    enable = true;
    settings = {
      user.name = "reuski";
      user.email = "sami@reuski.dev";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
  programs.jq.enable = true;
  programs.ripgrep.enable = true;
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
    theme = gruvboxDarkGtkTheme;
    gtk4.theme = gruvboxDarkGtkTheme;
    iconTheme = {
      package = pkgs.gruvbox-plus-icons;
      name = "Gruvbox-Plus-Dark";
    };
    font = {
      name = "Inter";
      size = 11;
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
}
