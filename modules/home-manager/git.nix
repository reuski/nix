{ ... }:
{
  flake.modules.homeManager.git =
    { config, ... }:
    {
      programs.git = {
        enable = true;
        settings = {
          user.name = config.profile.username;
          user.email = config.profile.email;
          init.defaultBranch = "main";
          pull.rebase = true;
        };
      };
    };
}
