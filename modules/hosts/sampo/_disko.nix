{ config, lib, ... }:
{
  services.fstrim.enable = lib.mkForce false;

  systemd.tmpfiles.rules = [
    "d /mnt/games 0755 ${config.profile.username} users -"
    "d /mnt/games/steam 0755 ${config.profile.username} users -"
    "d /mnt/games/heroic 0755 ${config.profile.username} users -"
  ];

  disko.devices = {
    disk = {
      system = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
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
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes."@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "discard=async"
                  ];
                };
              };
            };
          };
        };
      };

      games = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions.root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes."@games" = {
                mountpoint = "/mnt/games";
                mountOptions = [
                  "noatime"
                  "discard=async"
                ];
              };
            };
          };
        };
      };

      home = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions.root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes."@home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                  "discard=async"
                ];
              };
            };
          };
        };
      };

      nix = {
        type = "disk";
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions.root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes."@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                  "discard=async"
                ];
              };
            };
          };
        };
      };
    };
  };
}
