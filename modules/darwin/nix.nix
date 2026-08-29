{ ... }:
{
  flake.modules.darwin.nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      setsid = pkgs.writeCBin "nix-darwin-setsid" ''
        #include <sys/types.h>
        #include <sys/wait.h>
        #include <unistd.h>
        #include <stdio.h>
        #include <errno.h>

        int main(int argc, char **argv) {
          if (argc < 2) {
            fprintf(stderr, "usage: %s COMMAND [ARG...]\n", argv[0]);
            return 2;
          }

          pid_t pid = fork();
          if (pid < 0) {
            perror("fork");
            return 1;
          }

          if (pid == 0) {
            if (setsid() < 0) {
              perror("setsid");
              _exit(1);
            }
            execvp(argv[1], &argv[1]);
            perror("execvp");
            _exit(127);
          }

          int status;
          while (waitpid(pid, &status, 0) < 0) {
            if (errno != EINTR)
              return 1;
          }

          if (WIFEXITED(status))
            return WEXITSTATUS(status);
          if (WIFSIGNALED(status))
            return 128 + WTERMSIG(status);
          return 1;
        }
      '';
    in
    {
      nix.enable = true;
      nix.package = pkgs.nix;
      nix.channel.enable = false;
      nix.nixPath = [ ];

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ "@admin" ];
        extra-substituters = [ "https://reuski.cachix.org" ];
        extra-trusted-public-keys = [
          "reuski.cachix.org-1:eIWz4qd8JPuIm9XZxbfSQ802IhhJv2EarUiIG0IXSTs="
        ];
      };

      nix.gc = {
        automatic = true;
        interval = [
          {
            Weekday = 7;
            Hour = 3;
            Minute = 15;
          }
        ];
        options = "--delete-older-than 7d";
      };

      nix.optimise = {
        automatic = true;
        interval = [
          {
            Weekday = 7;
            Hour = 4;
            Minute = 15;
          }
        ];
      };

      launchd.daemons.nix-darwin-upgrade = {
        script = ''
          set -eu
          export HOME=/var/root
          exec ${lib.getExe setsid} ${lib.getExe config.system.build.darwin-rebuild} switch --flake github:reuski/nix/main#${config.networking.hostName} --refresh --option tarball-ttl 0
        '';
        serviceConfig = {
          RunAtLoad = false;
          StartCalendarInterval = [
            {
              Hour = 4;
              Minute = 30;
            }
          ];
          StandardOutPath = "/var/log/nix-darwin-upgrade.log";
          StandardErrorPath = "/var/log/nix-darwin-upgrade.err.log";
          Nice = 19;
          LowPriorityIO = true;
          ProcessType = "Background";
        };
      };
    };
}
