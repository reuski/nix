{ ... }:
{
  flake.modules.darwin.users =
    { config, lib, ... }:
    let
      user = config.profile.username;
      fish = "/etc/profiles/per-user/${user}/bin/fish";
      userRecord = "/Users/${user}";
    in
    {
      users.users.${user} = {
        name = user;
        home = config.profile.homeDirectory;
        shell = fish;
      };

      environment.shells = [ fish ];
      programs.bash.enable = false;
      programs.zsh.enable = false;
      programs.fish.enable = true;

      system.activationScripts.postActivation.text = lib.mkAfter ''
        currentShell=$(/usr/bin/dscl . -read ${lib.escapeShellArg userRecord} UserShell 2>/dev/null || true)
        currentShell=''${currentShell#UserShell: }

        if [ "$currentShell" != ${lib.escapeShellArg fish} ]; then
          if [ ! -x ${lib.escapeShellArg fish} ]; then
            printf >&2 'warning: fish shell %s is not executable; not changing login shell\n' ${lib.escapeShellArg fish}
          else
            echo "setting login shell for ${user}..." >&2
            /usr/bin/chsh -s ${lib.escapeShellArg fish} ${lib.escapeShellArg user}
          fi
        fi
      '';
    };
}
