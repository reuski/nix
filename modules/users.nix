{ pkgs, ... }:
{
  users.users.reuski = {
    isNormalUser = true;
    description = "reuski";
    hashedPassword = "$y$j9T$GErnHaaXaY3kHubPGs1h8.$0tIEdbq75t4mWHwuu4daaeQcGO6mgOVYCb/pItnCy62";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    shell = pkgs.fish;
  };

  users.users.root.hashedPassword = "!";

  programs.fish.enable = true;

  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = false;
  };
}
