{ ... }:
{
  flake.modules.nixos.plasma =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) getBin;
    in
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

      environment.plasma6.excludePackages =
        with pkgs.kdePackages;
        [
          ark
          aurorae
          baloo-widgets
          discover
          dolphin-plugins
          elisa
          ffmpegthumbs
          kate
          khelpcenter
          konsole
          krdp
          ktexteditor
          kwin-x11
          okular
          plasma-browser-integration
          plasma-workspace-wallpapers
          qrca
        ]
        ++ [ (getBin qttools) ];

      environment.systemPackages = with pkgs; [
        haruna
        p7zip
      ];

      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    };
}
