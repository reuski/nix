{ ... }:
{
  flake.modules.homeManager.colima =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.colima ];
    };
}
