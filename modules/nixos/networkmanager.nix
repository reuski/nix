{ ... }:
{
  flake.modules.nixos.networkmanager = {
    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      dns = "systemd-resolved";
    };
    networking.wireless.iwd.enable = true;

    networking.firewall.enable = true;
    networking.nftables.enable = true;

    services.resolved.enable = true;

    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
