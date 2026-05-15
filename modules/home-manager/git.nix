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
        };
      };
    };
}
