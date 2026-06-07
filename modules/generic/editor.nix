{ ... }:
{
  flake.modules.generic.editor =
    { lib, ... }:
    {
      options.editor.vimConfig = lib.mkOption {
        type = lib.types.lines;
        description = "Shared vimrc applied to system and Home Manager Vim.";
      };

      config.editor.vimConfig = ''
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
}
