{ lib, ... }:
{
  services.tailscale = {
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--ssh"
      "--advertise-connector"
    ];
  };

  systemd.network.networks."10-wan" = {
    networkConfig.DHCP = lib.mkForce "no";
    address = [ "192.168.1.11/24" ];
    gateway = [ "192.168.1.1" ];
  };
}
