{ ... }:
{
  flake.modules.homeManager.packages =
    { pkgs, ... }:
    {
      home.file."Pictures/Screenshots/.keep".text = "";

      home.packages = with pkgs; [
        helium-browser
        wl-clipboard
        brightnessctl
        playerctl
        grim
        slurp
        imv
        zellij
      ];
    };
}
