{ ... }:
{
  flake.modules.homeManager.git =
    { config, ... }:
    {
      programs.git = {
        enable = true;
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
