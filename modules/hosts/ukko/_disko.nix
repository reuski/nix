{ ... }:
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/nvme-PC711_NVMe_SK_hynix_512GB____FNB2N597512002F0K";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            size = "512M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };

  fileSystems."/srv/media" = {
    device = "/dev/disk/by-partlabel/disk-media-root";
    fsType = "ext4";
    options = [ "noatime" ];
  };
}
