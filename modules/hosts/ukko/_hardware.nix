{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "i915"
  ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "i915.enable_guc=3" ];

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault true;
    enableRedistributableFirmware = lib.mkDefault true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-compute-runtime
        intel-media-driver
        vpl-gpu-rt
      ];
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General.Experimental = true;
        Policy.AutoEnable = true;
      };
    };
  };

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

  services.fwupd.enable = true;
  services.thermald.enable = true;

  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
  environment.systemPackages = with pkgs; [
    bluez
    intel-gpu-tools
    iw
    iwd
    libva-utils
    pciutils
    usbutils
  ];

  systemd.services.jellyfin = lib.mkIf config.services.jellyfin.enable {
    environment.LIBVA_DRIVER_NAME = "iHD";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
