{ ... }:
{
  flake.modules.nixos.users =
    { config, pkgs, ... }:
    {
      programs.fish.enable = true;

      sops.secrets."users/${config.profile.username}/password" = {
        neededForUsers = true;
        sopsFile = ../../secrets/users.yaml;
      };

      users.users.${config.profile.username} = {
        hashedPasswordFile = config.sops.secrets."users/${config.profile.username}/password".path;
        extraGroups = [
          "networkmanager"
          "video"
        ];
        shell = pkgs.fish;
      };
    };
}
