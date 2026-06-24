{ config, ... }:
{
  home-manager.users.${config.profile.username}.wallpaper = {
    primary = "range";
    screens = [
      "range"
      "forage"
      "mountain"
    ];
  };
}
