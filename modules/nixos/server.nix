{ ... }:
{
  flake.modules.nixos.server =
    {
      config,
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;
      boot.tmp.cleanOnBoot = true;

      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
      };

      systemd.oomd.enable = true;
      systemd.coredump.enable = false;

      networking = {
        useDHCP = false;
        useNetworkd = true;
        nftables.enable = true;
        firewall = {
          enable = true;
          logRefusedConnections = false;
        };
      };

      systemd.network = {
        enable = true;
        wait-online.anyInterface = true;
        networks."10-wan" = {
          matchConfig.Name = "en* eth* ens*";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
          };
          linkConfig.RequiredForOnline = "routable";
        };
      };

      services.resolved.enable = true;
      services.timesyncd.enable = true;

      services.openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [ config.profile.username ];
          X11Forwarding = false;
          AllowAgentForwarding = false;
          AllowTcpForwarding = false;
          PermitTunnel = false;
        };
      };

      users.mutableUsers = false;
      users.users.${config.profile.username} = {
        isNormalUser = true;
        description = config.profile.fullName;
        home = config.profile.homeDirectory;
        hashedPassword = "!";
        extraGroups = [ "wheel" ];
        shell = pkgs.fish;
      };
      users.users.root.hashedPassword = "!";

      programs.fish.enable = true;

      security.sudo.enable = false;
      security.sudo-rs = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };

      services.journald.extraConfig = ''
        SystemMaxUse=500M
        RuntimeMaxUse=100M
      '';

      environment.systemPackages = with pkgs; [
        curl
        git
      ];
    };
}
