{ ... }:
{
  flake.modules.nixos.plasma =
    {
      config,
      pkgs,
      ...
    }:
    {
      services.displayManager = {
        autoLogin = {
          enable = true;
          user = config.profile.username;
        };
        plasma-login-manager.enable = true;
      };

      services.desktopManager.plasma6 = {
        enable = true;
        enableQt5Integration = false;
      };

      programs.kde-pim.enable = false;
      services.orca.enable = false;

      environment.plasma6.excludePackages = with pkgs.kdePackages; [
        aurorae
        baloo-widgets
        discover
        dolphin-plugins
        elisa
        kate
        khelpcenter
        konsole
        krdp
        kwin-x11
        okular
        plasma-browser-integration
        plasma-workspace-wallpapers
        qrca
      ];

      environment.systemPackages = with pkgs; [
        haruna
        p7zip
      ];

      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    };
}
