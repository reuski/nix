{ ... }:
{
  flake.modules.darwin.users =
    { config, ... }:
    let
      fish = "/etc/profiles/per-user/${config.profile.username}/bin/fish";
    in
    {
      users.users.${config.profile.username} = {
        name = config.profile.username;
        home = config.profile.homeDirectory;
        shell = fish;
      };

      environment.shells = [ fish ];
      programs.fish.enable = true;
    };
}
