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

      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };

      programs.gamemode = {
        enable = true;
        enableRenice = true;
      };

      hardware.steam-hardware.enable = true;
      hardware.graphics.enable32Bit = true;

      environment.sessionVariables = {
        PROTON_ENABLE_WAYLAND = "1";
        PROTON_ENABLE_HDR = "1";
        PROTON_DLSS_UPGRADE = "1";
        PROTON_XESS_UPGRADE = "1";
        PROTON_FSR4_UPGRADE = "1";
        VKD3D_CONFIG = "dxr,dxr11";
        ENABLE_HDR_WSI = "1";
      };

      environment.systemPackages = [ pkgs.heroic ];
    };
}
