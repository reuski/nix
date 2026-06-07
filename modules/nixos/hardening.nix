{ ... }:
{
  flake.modules.nixos.hardening =
    { ... }:
    {
      boot.kernel.sysctl = {
        "kernel.dmesg_restrict" = 1;
        "kernel.kptr_restrict" = 2;
      };

      systemd.coredump.enable = false;

      security.apparmor.enable = true;
      security.protectKernelImage = true;
    };
}
