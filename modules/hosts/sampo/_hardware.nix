{ inputs }:

{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  currentKernelPkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  pinnedZenKernel =
    (import inputs.nixpkgs-zen-kernel {
      inherit system;
    }).linuxPackages_zen.kernel;
in
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
  boot.kernelModules = [
    "kvm-intel"
    "ntsync"
  ];

  boot.kernelPackages = lib.mkForce (currentKernelPkgs.linuxPackagesFor pinnedZenKernel);
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
    scheduler = "scx_flash";
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.bluetooth.enable = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  services.fwupd.enable = true;

  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  environment.sessionVariables = {
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_SIZE = "12000000000";
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
    __GL_MaxFramesAllowed = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
