{ darwin, homeManager }:
{ config, ... }:
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
