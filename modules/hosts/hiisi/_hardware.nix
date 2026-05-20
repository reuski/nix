{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  systemctl = lib.getExe' config.systemd.package "systemctl";
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "thinkpad_acpi"
  ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    "acpi_backlight=native"
    "mem_sleep_default=deep"
    "nosgx"
    "btusb.enable_autosuspend=0"
  ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
    settings.General.Experimental = true;
  };
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  systemd.packages = [ pkgs.open-fprintd ];
  services.dbus.packages = [
    pkgs.open-fprintd
    pkgs.python-validity
  ];

  systemd.tmpfiles.rules = [ "d /var/lib/python-validity 0755 root root -" ];

  systemd.services.open-fprintd.wantedBy = [ "multi-user.target" ];

  security.pam.services.greetd.fprintAuth = true;
  security.pam.services.login.fprintAuth = true;

  services.udev.extraRules = ''
    SUBSYSTEM!="usb", GOTO="python_validity_end"
    ENV{DEVTYPE}!="usb_device", GOTO="python_validity_end"

    ATTRS{idVendor}=="138a", ATTRS{idProduct}=="0090", GOTO="python_validity_match"
    ATTRS{idVendor}=="138a", ATTRS{idProduct}=="0097", GOTO="python_validity_match"
    ATTRS{idVendor}=="06cb", ATTRS{idProduct}=="009a", GOTO="python_validity_match"

    GOTO="python_validity_end"

    LABEL="python_validity_match"

    ACTION=="add|change", ATTR{power/control}="auto", RUN+="${systemctl} --no-block start python3-validity.service"
    ACTION=="remove", RUN+="${systemctl} --no-block stop python3-validity.service"

    LABEL="python_validity_end"
  '';

  systemd.services.python3-validity = {
    description = "python-validity driver dbus service";
    after = [ "open-fprintd.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python-validity}/lib/python-validity/dbus-service";
      Restart = "no";
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
