{
  config,
  lib,
  pkgs,
  ...
}:
{
  web = {
    sites.reuski-dev = {
      domain = "reuski.dev";
      aliases = [ "www.reuski.dev" ];
      package = pkgs.web-reuski-dev;
      extraConfig = ''
        @atprotoDid path /.well-known/atproto-did
        respond @atprotoDid "did:plc:igxk22uwwycyvrhxxwz2zevj" 200
      '';
    };

    services = {
      beebud = {
        domain = "beebud.buzz";
        aliases = [ "www.beebud.buzz" ];
        package = pkgs.web-beebud;
        port = 3001;
        envFile = config.sops.secrets."web/beebud/env".path;
      };

      wahuu-games = {
        domain = "wahuu.games";
        aliases = [ "www.wahuu.games" ];
        package = pkgs.web-wahuu-games;
        port = 3000;
        envFile = config.sops.secrets."web/wahuu-games/env".path;
      };

      juttu = {
        package = pkgs.web-juttu;
        port = 3003;
        envFile = config.sops.secrets."web/juttu/env".path;
      };
    };
  };

  tailnet.services.juttu.port = config.web.services.juttu.port;

  systemd.services.web-juttu.serviceConfig.RestrictAddressFamilies = lib.mkForce [
    "AF_INET"
    "AF_UNIX"
  ];

  sops.secrets = {
    "web/beebud/env" = {
      owner = config.web.user;
      group = config.web.group;
      mode = "0400";
      restartUnits = [ "web-beebud.service" ];
    };
    "web/wahuu-games/env" = {
      owner = config.web.user;
      group = config.web.group;
      mode = "0400";
      restartUnits = [ "web-wahuu-games.service" ];
    };
    "web/juttu/env" = {
      owner = config.web.user;
      group = config.web.group;
      mode = "0400";
      restartUnits = [ "web-juttu.service" ];
    };
  };
}
