{ ... }:
{
  flake.modules.homeManager.colima =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.colima
        pkgs.docker-client
        pkgs.docker-compose
      ];
    };
}
