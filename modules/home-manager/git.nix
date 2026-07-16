{ ... }:
{
  flake.modules.homeManager.git =
    { config, ... }:
    {
      programs.git = {
        enable = true;
        ignores = [
          "AGENTS.md"
          ".DS_Store"
          ".AppleDouble"
          ".LSOverride"
          "._*"
          ".Spotlight-V100"
          ".TemporaryItems"
          ".Trashes"
          ".fseventsd"
          ".localized"
          "__MACOSX/"
          ".directory"
          ".Trash-*"
          ".fuse_hidden*"
          ".nfs*"
          "nohup.out"
          "*~"
          "[._]*.s[a-v][a-z]"
          "[._]*.sw[a-p]"
          "[._]*.un~"
          "Session.vim"
          "Sessionx.vim"
          ".netrwhist"
          ".direnv/"
          ".devenv/"
          ".env"
          ".env.local"
          ".env.*.local"
          ".pi-subagents/"
        ];
        settings = {
          user.name = config.profile.fullName;
          user.email = config.profile.email;
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
          fetch.prune = true;
          rebase.autoStash = true;
          diff.algorithm = "histogram";
          merge.conflictStyle = "zdiff3";
        };
      };
    };
}
