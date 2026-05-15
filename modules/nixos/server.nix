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
      boot.kernelModules = [ "tcp_bbr" ];
      boot.kernel.sysctl = {
        "kernel.dmesg_restrict" = 1;
        "kernel.kptr_restrict" = 2;
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };
      boot.tmp.cleanOnBoot = true;

      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
      };

      systemd.oomd.enable = true;
      systemd.coredump.enable = false;
      systemd.targets = {
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = false;
        hybrid-sleep.enable = false;
      };

      environment.defaultPackages = [ ];

      networking = {
        useDHCP = false;
        useNetworkd = true;
        nftables.enable = true;
        firewall = {
          enable = true;
          allowPing = true;
          checkReversePath = "loose";
          logRefusedConnections = false;
          trustedInterfaces = [ "tailscale0" ];
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
            LinkLocalAddressing = "ipv6";
          };
          linkConfig.RequiredForOnline = "routable";
        };
      };

      services.resolved = {
        enable = true;
        dnssec = "allow-downgrade";
        dnsovertls = "opportunistic";
        fallbackDns = [
          "1.1.1.1#cloudflare-dns.com"
          "9.9.9.9#dns.quad9.net"
        ];
      };
      services.fstrim.enable = true;
      services.timesyncd.enable = true;

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
      security.apparmor.enable = true;
      security.protectKernelImage = true;

      services.journald.extraConfig = ''
        SystemMaxUse=500M
        RuntimeMaxUse=100M
        MaxRetentionSec=1month
      '';

      environment.systemPackages = with pkgs; [
        curl
        dnsutils
        git
        jq
        lsof
        rsync
        tcpdump
      ];
    };
}
