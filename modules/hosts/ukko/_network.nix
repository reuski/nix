{ config, lib, ... }:
let
  tailnetServePorts = lib.unique (
    [
      80
      443
    ]
    ++ lib.mapAttrsToList (_: service: service.https) config.tailnet.services
  );
in
{
  networking.firewall = {
    trustedInterfaces = lib.mkForce [ "lo" ];
    interfaces.tailscale0.allowedTCPPorts = tailnetServePorts;
  };

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
