{ inputs, ... }:
{
  flake.modules.nixos.podman =
    { config, lib, ... }:
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      virtualisation.quadlet = {
        enable = lib.mkDefault (
          config.virtualisation.quadlet.containers != { } || config.virtualisation.quadlet.pods != { }
        );
        autoUpdate.enable = lib.mkDefault true;
      };
    };
}
