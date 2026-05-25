{ ... }:
{
  flake.modules.homeManager.postgres =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.postgresql_18 ];
    };
}
