{ inputs, ... }:
{
  flake.modules.nixos.podman =
    { lib, ... }:
    {
      imports = [ inputs.quadlet-nix.nixosModules.quadlet ];

      virtualisation.quadlet.autoUpdate.enable = lib.mkDefault true;
    };
}
