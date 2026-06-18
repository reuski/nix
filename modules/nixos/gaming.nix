{ ... }:
{
  flake.modules.nixos.gaming =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        gamescopeSession.enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        remotePlay.openFirewall = true;
      };

      programs.gamescope.enable = true;

      programs.gamemode = {
        enable = true;
        enableRenice = true;
      };

      hardware.steam-hardware.enable = true;
      hardware.graphics.enable32Bit = true;

      environment.systemPackages = [ pkgs.heroic ];
    };
}
