{ ... }:
{
  flake.modules.nixos.gaming =
    { config, pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
      };

      programs.gamemode = {
        enable = true;
        enableRenice = true;
      };

      hardware.steam-hardware.enable = true;
      hardware.uinput.enable = true;
      hardware.graphics.enable32Bit = true;

      systemd.user.tmpfiles.rules = [
        "d %h/.local/share/Steam/compatibilitytools.d 0755 - - -"
        "L+ %h/.local/share/Steam/compatibilitytools.d/Proton-GE - - - - ${pkgs.proton-ge-bin.steamcompattool}"
      ];

      environment.sessionVariables = {
        VKD3D_CONFIG = "dxr";
      };

      users.users.${config.profile.username}.extraGroups = [ "uinput" ];

      environment.systemPackages = [ pkgs.heroic ];
    };
}
