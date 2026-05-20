{ ... }:
{
  flake.modules.nixos.connectivity =
    { pkgs, ... }:
    {
      networking.wireless.iwd = {
        enable = true;
        settings = {
          General.EnableNetworkConfiguration = false;
          Settings.AutoConnect = true;
        };
      };

      systemd.network.networks."20-wifi" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
          LinkLocalAddressing = "ipv6";
        };
        dhcpV4Config.RouteMetric = 600;
        ipv6AcceptRAConfig.RouteMetric = 600;
        linkConfig.RequiredForOnline = "routable";
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General.Experimental = true;
          Policy.AutoEnable = true;
        };
      };

      services.fwupd.enable = true;
      services.thermald.enable = true;

      environment.systemPackages = with pkgs; [
        bluez
        iw
        iwd
        pciutils
        usbutils
      ];
    };
}
