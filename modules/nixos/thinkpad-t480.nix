{ ... }:
{
  flake.modules.nixos.thinkpadT480 =
    { lib, pkgs, ... }:
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

      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];

      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
    };
}
