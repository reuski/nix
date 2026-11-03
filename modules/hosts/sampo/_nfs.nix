{ lib, ... }:
{
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce true;

  fileSystems."/mnt/ukko" = {
    device = "192.168.1.11:/";
    fsType = "nfs";
    options = [
      "rw"
      "vers=4.2"
      "proto=tcp"
      "hard"
      "_netdev"
      "nosuid"
      "nodev"
      "nofail"
      "x-systemd.mount-timeout=10s"
    ];
  };
}
