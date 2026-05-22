{ ... }:
{
  flake.modules.darwin.apps =
    { config, pkgs, ... }:
    {
      services.tailscale.enable = true;

      home-manager.users.${config.profile.username}.home.packages = [ pkgs.localsend ];
    };
}
