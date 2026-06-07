{ ... }:
{
  flake.modules.nixos.ssh =
    { config, pkgs, ... }:
    {
      services.openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          AuthenticationMethods = "publickey";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [ config.profile.username ];
          ClientAliveCountMax = 2;
          ClientAliveInterval = 300;
          LoginGraceTime = "30s";
          LogLevel = "VERBOSE";
          MaxAuthTries = 3;
          X11Forwarding = false;
          AllowAgentForwarding = false;
          AllowTcpForwarding = false;
          PermitTunnel = false;
        };
      };

      users.users.${config.profile.username} = {
        hashedPassword = "!";
        shell = pkgs.bashInteractive;
        openssh.authorizedKeys.keys = config.profile.sshAuthorizedKeys;
      };
    };
}
