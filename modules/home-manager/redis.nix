{ ... }:
{
  flake.modules.homeManager.redis =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.redis ];
    };
}
