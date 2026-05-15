{ ... }:
{
  flake.modules.darwin.users =
    { config, pkgs, ... }:
    {
      users.users.${config.profile.username} = {
        name = config.profile.username;
        home = config.profile.homeDirectory;
        shell = pkgs.fish;
      };

      programs.fish.enable = true;
    };
}
