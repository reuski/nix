{ pkgs, ... }:
let
  niriPackage = pkgs.niri-unstable;
in
{
  programs.niri = {
    enable = true;
    package = niriPackage;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd ${niriPackage}/bin/niri-session";
      user = "greeter";
    };
  };

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  security.polkit.enable = true;
  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_BACKEND = "wayland";
    XDG_SESSION_TYPE = "wayland";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    inter
  ];
  fonts.fontconfig.defaultFonts = {
    monospace = [ "Hack Nerd Font" ];
    sansSerif = [
      "Inter"
      "Noto Sans"
      "Noto Color Emoji"
    ];
    serif = [
      "Noto Serif"
      "Noto Color Emoji"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter -"
    "d /home/reuski/Pictures/Screenshots 0755 reuski users -"
  ];
}
