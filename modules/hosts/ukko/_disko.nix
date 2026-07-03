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

    disk.media = {
      device = "/dev/disk/by-id/nvme-CT4000P3SSD8_2422E8B582A9";
      type = "disk";
      content = {
        type = "gpt";
        partitions.root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [
              "-L"
              "media"
              "-m"
              "0"
            ];
            mountpoint = "/srv/media";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
