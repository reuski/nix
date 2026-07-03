{ ... }:
{
  flake.modules.nixos.gaming =
    { config, pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
      };

      powerManagement.cpuFreqGovernor = "performance";

      hardware.steam-hardware.enable = true;
      hardware.uinput.enable = true;
      hardware.graphics.enable32Bit = true;

      systemd.user.tmpfiles.rules = [
        "d %h/.local/share/Steam/compatibilitytools.d 0755 - - -"
        "L+ %h/.local/share/Steam/compatibilitytools.d/Proton-GE - - - - ${pkgs.proton-ge-bin.steamcompattool}"
      ];

      users.users.${config.profile.username}.extraGroups = [ "uinput" ];

      environment.systemPackages = [ pkgs.heroic ];
    };
}
