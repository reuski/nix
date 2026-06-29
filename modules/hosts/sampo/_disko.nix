{ config, lib, ... }:
let
  inherit (config.profile) username homeDirectory;

  btrfsOpts = [
    "compress=zstd"
    "noatime"
    "discard=async"
  ];

  dataDisk = device: subvolume: mountpoint: mountOptions: {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions.root = {
        size = "100%";
        content = {
          type = "btrfs";
          extraArgs = [ "-f" ];
          subvolumes.${subvolume} = { inherit mountpoint mountOptions; };
        };
      };
    };
  };
in
{
  services.fstrim.enable = lib.mkForce false;

  systemd.tmpfiles.rules = [
    "d ${homeDirectory}/games/steam 0755 ${username} users -"
    "d ${homeDirectory}/games/heroic 0755 ${username} users -"
  ];

  disko.devices.disk = {
    system = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_250GB_S4EUNF0M442448X";
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
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = btrfsOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOpts;
                };
              };
            };
          };
        };
      };
    };

    games =
      dataDisk "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7DNNU0X746013X" "@games"
        "${homeDirectory}/games"
        [
          "noatime"
          "discard=async"
        ];

    home =
      dataDisk "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RBNX0H821702X" "@home" "/home"
        btrfsOpts;

    projects =
      dataDisk "/dev/disk/by-id/ata-Samsung_SSD_850_PRO_256GB_S1SUNSAG365733F" "@projects"
        "${homeDirectory}/projects"
        btrfsOpts;
  };

  fileSystems.storage = {
    device = "/dev/disk/by-id/wwn-0x5000c500e797fcc5";
    fsType = "btrfs";
    mountPoint = "${homeDirectory}/storage";
    options = [
      "noatime"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=10min"
    ];
  };
}
