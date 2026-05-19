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
        isNormalUser = true;
        description = config.profile.fullName;
        home = config.profile.homeDirectory;
        hashedPasswordFile = config.sops.secrets."users/${config.profile.username}/password".path;
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
        ];
        shell = pkgs.fish;
      };
    };
}
