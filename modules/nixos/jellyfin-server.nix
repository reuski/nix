{ ... }:
{
  flake.modules.nixos.jellyfinServer =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.services.jellyfin.enable {
      boot.kernel.sysctl = {
        "fs.inotify.max_user_instances" = 1024;
        "fs.inotify.max_user_watches" = 1048576;
      };

      fonts = {
        fontconfig.enable = lib.mkForce true;
        packages = with pkgs; [
          liberation_ttf
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
        ];
      };

      environment.systemPackages = with pkgs; [
        intel-gpu-tools
        libva-utils
      ];

      systemd.services.jellyfin = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          UMask = lib.mkForce "0002";
          SupplementaryGroups = [
            "media"
            "render"
            "video"
          ];
        };
      };
    };
}
