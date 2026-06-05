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
      repo = "https://github.com/reuski/reuski.dev.git";
      extraConfig = ''
        @atprotoDid path /.well-known/atproto-did
        respond @atprotoDid "did:plc:igxk22uwwycyvrhxxwz2zevj" 200
      '';
    };

    services = {
      beebud = {
        domain = "beebud.buzz";
        aliases = [ "www.beebud.buzz" ];
        repo = "https://github.com/reuski/beebud.git";
        port = 3001;
        start = "${lib.getExe pkgs.bun} build/index.js";
        envFile = config.sops.secrets."web/beebud/env".path;
      };

      wahuu-games = {
        domain = "wahuu.games";
        aliases = [ "www.wahuu.games" ];
        repo = "https://github.com/reuski/wahuu.games.git";
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
      restartUnits = [ "web-service-beebud.service" ];
    };
    "web/wahuu-games/env" = {
      owner = config.web.user;
      group = config.web.group;
      mode = "0400";
      restartUnits = [ "web-service-wahuu-games.service" ];
    };
  };
}
