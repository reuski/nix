{ inputs, ... }:
{
  flake.modules.darwin.homebrew =
    { config, ... }:
    let
      brew = "${config.homebrew.prefix}/bin/brew";
      runAsUser = "/usr/bin/sudo --preserve-env=PATH --user=${config.homebrew.user} --set-home";
    in
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

      nix-homebrew = {
        enable = true;
        user = config.profile.username;
      };

      homebrew = {
        enable = true;
        greedyCasks = true;
        global.autoUpdate = false;
        onActivation = {
          cleanup = "uninstall";
        };
      };

      launchd.daemons.homebrew-upgrade = {
        script = ''
          set -eu
          ${runAsUser} ${brew} update
          ${runAsUser} ${brew} upgrade --greedy
        '';
        serviceConfig = {
          RunAtLoad = false;
          StartCalendarInterval = [
            {
              Hour = 5;
              Minute = 0;
            }
          ];
          StandardOutPath = "/var/log/homebrew-upgrade.log";
          StandardErrorPath = "/var/log/homebrew-upgrade.err.log";
          Nice = 19;
          LowPriorityIO = true;
          ProcessType = "Background";
        };
      };
    };
}
