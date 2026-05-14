{ ... }:
{
  flake.modules.nixos.thinkpadT480 =
    { lib, ... }:
    {
      hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
      hardware.enableRedistributableFirmware = lib.mkDefault true;

      boot.kernelModules = [ "thinkpad_acpi" ];
      boot.kernelParams = [
        "acpi_backlight=native"
        "mem_sleep_default=deep"
        "nosgx"
        "btusb.enable_autosuspend=0"
      ];
    };
}
