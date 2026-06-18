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
    "nvme"
    "vmd"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
    "uas"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "nowatchdog"
    "usbcore.autosuspend=-1"
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];

  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  services.fwupd.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment.sessionVariables = {
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
