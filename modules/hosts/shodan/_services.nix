{
  config,
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
    };
  };

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
  };
}
