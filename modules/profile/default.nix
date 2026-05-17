{ ... }:
{
  flake.modules.generic.profile =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.profile = {
        username = lib.mkOption { type = lib.types.str; };
        fullName = lib.mkOption { type = lib.types.str; };
        email = lib.mkOption { type = lib.types.str; };
        homeDirectory = lib.mkOption { type = lib.types.str; };
        timeZone = lib.mkOption { type = lib.types.str; };
        locale = {
          default = lib.mkOption { type = lib.types.str; };
          regional = lib.mkOption { type = lib.types.str; };
        };
        keyboard = {
          model = lib.mkOption { type = lib.types.str; };
          layout = lib.mkOption { type = lib.types.str; };
          variant = lib.mkOption { type = lib.types.str; };
          options = lib.mkOption { type = lib.types.str; };
        };
        colors.gruvbox = lib.mkOption { type = lib.types.attrsOf lib.types.str; };
        editor.vimConfig = lib.mkOption { type = lib.types.lines; };
      };

      config.profile = {
        username = lib.mkDefault "reuski";
        fullName = lib.mkDefault "reuski";
        email = lib.mkDefault "sami@reuski.dev";
        homeDirectory = lib.mkDefault (
          if pkgs.stdenv.hostPlatform.isDarwin then
            "/Users/${config.profile.username}"
          else
            "/home/${config.profile.username}"
        );
        timeZone = lib.mkDefault "Europe/Helsinki";
        locale = {
          default = lib.mkDefault "en_US.UTF-8";
          regional = lib.mkDefault "fi_FI.UTF-8";
        };
        keyboard = {
          model = lib.mkDefault "pc105";
          layout = lib.mkDefault "fi";
          variant = lib.mkDefault "nodeadkeys";
          options = lib.mkDefault "";
        };
        colors.gruvbox = {
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
          black = "#1d2021";
          white = "#a89984";
        };
        editor.vimConfig = lib.mkDefault ''
          set encoding=utf-8
          set background=dark
          if has("termguicolors")
            set termguicolors
          endif
          colorscheme gruvbox
          syntax on
          filetype plugin indent on

          let mapleader = " "

          set number
          set relativenumber
          set cursorline
          set signcolumn=yes
          set scrolloff=5
          set sidescrolloff=8
          set linebreak
          set breakindent
          set display+=lastline
          set laststatus=3

          set expandtab
          set shiftwidth=2
          set softtabstop=-1
          set tabstop=2
          set shiftround

          set hidden
          set splitbelow
          set splitright
          set autoread
          set wildmenu
          set wildmode=longest:full,full
          set completeopt=menuone,noselect
          set pumheight=12
          set updatetime=250
          set timeoutlen=350
          set shortmess+=c

          set ignorecase
          set smartcase
          set incsearch
          set hlsearch

          set backupcopy=yes
          set mouse=a
          set nomodeline
          set listchars=tab:>-,trail:.,extends:>,precedes:<,nbsp:+

          if has("persistent_undo")
            let s:cache = expand("~/.cache/vim")
            call mkdir(s:cache . "/undo", "p", 0700)
            call mkdir(s:cache . "/swap", "p", 0700)
            execute "set undodir=" . fnameescape(s:cache . "/undo//")
            execute "set directory=" . fnameescape(s:cache . "/swap//") . ",."
            set undofile
          endif

          if has("clipboard")
            set clipboard=unnamedplus
          endif

          if exists("&smoothscroll")
            set smoothscroll
          endif
          if exists("&splitkeep")
            set splitkeep=screen
          endif
          if exists("&wildoptions")
            set wildoptions=pum
          endif
          if exists("&winborder")
            set winborder=rounded
          endif
          if exists("&inccommand")
            set inccommand=nosplit
          endif
          if has("popupwin")
            set completeopt+=popup
          endif

          augroup profile_vim
            autocmd!
            autocmd FocusGained,BufEnter * checktime
            autocmd FileType * setlocal formatoptions-=cro
          augroup END

          nnoremap <leader>w <Cmd>write<CR>
          nnoremap <leader>q <Cmd>quit<CR>
          nnoremap <leader>h <Cmd>nohlsearch<CR>
          nnoremap <leader>l <Cmd>set list!<CR>
          nnoremap <C-h> <C-w>h
          nnoremap <C-j> <C-w>j
          nnoremap <C-k> <C-w>k
          nnoremap <C-l> <C-w>l
          tnoremap <Esc><Esc> <C-\><C-n>
        '';
      };
    };
}
