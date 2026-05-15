{ ... }:
{
  flake.modules.homeManager.python =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.python314
        pkgs.uv
      ];
    };
}
