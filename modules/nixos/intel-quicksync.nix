{ ... }:
{
  flake.modules.nixos.intelQuickSync =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      boot.kernelModules = [ "i915" ];
      boot.kernelParams = [ "i915.enable_guc=3" ];

      hardware = {
        enableRedistributableFirmware = lib.mkDefault true;
        graphics = {
          enable = true;
          extraPackages = with pkgs; [
            intel-compute-runtime
            intel-media-driver
            vpl-gpu-rt
          ];
        };
      };

      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

      systemd.services.jellyfin = lib.mkIf config.services.jellyfin.enable {
        environment.LIBVA_DRIVER_NAME = "iHD";
      };
    };
}
