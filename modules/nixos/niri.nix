{ inputs, ... }:
{
  flake.modules.nixos.niri =
    { lib, pkgs, ... }:
    let
      niriPackage = pkgs.niri;
      niriSession = lib.getExe' niriPackage "niri-session";
      tuigreet = lib.getExe pkgs.tuigreet;
      greetdSession = pkgs.writeShellScript "greetd-niri-session" ''
        . /etc/set-environment
        exec ${niriSession}
      '';
    in
    {
      imports = [ inputs.niri.nixosModules.niri ];

      niri-flake.cache.enable = false;

      programs.niri = {
        enable = true;
        package = niriPackage;
      };

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${tuigreet} --time --remember --cmd ${greetdSession}";
          user = "greeter";
        };
      };

      xdg.portal.xdgOpenUsePortal = true;
      security.pam.services.greetd.enableGnomeKeyring = true;

      environment.sessionVariables = {
        QT_QPA_PLATFORM = "wayland";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      };

      systemd.tmpfiles.rules = [
        "d /var/cache/tuigreet 0755 greeter greeter -"
      ];
    };
}
