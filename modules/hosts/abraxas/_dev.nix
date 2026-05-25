{ config, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
in
{
  imports = [
    darwin.zed
    darwin.tableplus
  ];

  home-manager.users.${config.profile.username}.imports = [
    homeManager.dev
    homeManager.colima
    homeManager.postgres
    homeManager.redis
  ];
}
