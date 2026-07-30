{ ... }:
{
  flake.modules.nixos.sabnzbd =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.sabnzbd;
      media = config.media;
      downloadDir = "${media.libraryDir}/usenet";
      port = 8081;
      inherit (lib) mkEnableOption mkIf;
    in
    {
      options.sabnzbd.enable = mkEnableOption "SABnzbd usenet downloader";

      config = mkIf cfg.enable {
        services.sabnzbd = {
          enable = true;
          user = media.user;
          group = media.group;
          allowConfigWrite = true;
          secretValues."@sabnzbd_api_key@" = config.sops.secrets."sabnzbd/api-key".path;
          settings.misc = {
            host = "127.0.0.1";
            inherit port;
            api_key = "@sabnzbd_api_key@";
            download_dir = "${downloadDir}/incomplete";
            complete_dir = "${downloadDir}/complete";
            permissions = "775";
            inet_exposure = "none";
            host_whitelist = config.proxy.services.sabnzbd.domain;
          };
        };

        proxy.services.sabnzbd.port = port;

        media.directories = {
          ${downloadDir} = { };
          "${downloadDir}/incomplete" = { };
          "${downloadDir}/complete" = { };
        };
      };
    };
}
