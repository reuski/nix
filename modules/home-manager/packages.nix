{ ... }:
{
  flake.modules.homeManager.packages =
    { pkgs, ... }:
    {
      home.file."pictures/Screenshots/.keep".text = "";

      home.packages = with pkgs; [
        helium-browser
        flare-signal
        wl-clipboard
        brightnessctl
        playerctl
        imv
      ];
    };
}
