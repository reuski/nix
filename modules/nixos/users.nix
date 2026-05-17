{ ... }:
{
  flake.modules.nixos.users =
    { config, pkgs, ... }:
    {
      programs.fish.enable = true;

      users.users.${config.profile.username} = {
        isNormalUser = true;
        description = config.profile.fullName;
        home = config.profile.homeDirectory;
        hashedPassword = "$y$j9T$GErnHaaXaY3kHubPGs1h8.$0tIEdbq75t4mWHwuu4daaeQcGO6mgOVYCb/pItnCy62";
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
        ];
        shell = pkgs.fish;
      };
    };
}
