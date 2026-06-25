{ ... }:
{
  flake.modules.nixos.cache =
    {
      config,
      pkgs,
      ...
    }:
    {
      sops.secrets."attic/server-token" = { };
      sops.secrets."attic/push-token" = { };

      sops.templates."atticd-env".content = ''
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder."attic/server-token"}
      '';

      systemd.tmpfiles.rules = [ "d /root/.config/attic 0700 root root -" ];

      sops.templates."attic-client".path = "/root/.config/attic/config.toml";
      sops.templates."attic-client".content = ''
        default-server = "ukko"

        [servers.ukko]
        endpoint = "http://127.0.0.1:8090/"
        token = "${config.sops.placeholder."attic/push-token"}"
      '';

      services.atticd = {
        enable = true;
        environmentFile = config.sops.templates."atticd-env".path;
        settings = {
          listen = "127.0.0.1:8090";
          api-endpoint = "https://ukko.tail2fc4c2.ts.net:8090/";
          chunking = {
            nar-size-threshold = 65536;
            min-size = 16384;
            avg-size = 65536;
            max-size = 262144;
          };
          compression.type = "zstd";
          garbage-collection = {
            interval = "12 hours";
            default-retention-period = "1 month";
          };
        };
      };

      environment.systemPackages = [ pkgs.attic-client ];

      tailnet.services.attic.port = 8090;
    };
}
