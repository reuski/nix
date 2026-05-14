{
  config,
  inputs,
  lib,
  ...
}:
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
          default = { };
          description = "NixOS module for this configuration.";
        };
      }
    );
    default = { };
    description = "NixOS system configurations.";
  };

  config.flake = {
    nixosConfigurations = lib.mapAttrs (
      name: cfg:
      inputs.nixpkgs.lib.nixosSystem {
        modules = [
          inputs.home-manager.nixosModules.home-manager
          {
            networking.hostName = lib.mkDefault name;
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
            };
          }
          cfg.module
        ];
      }
    ) config.configurations.nixos;

    checks = lib.foldlAttrs (
      acc: name: _cfg:
      let
        nixos = config.flake.nixosConfigurations.${name};
        inherit (nixos.config.nixpkgs.hostPlatform) system;
      in
      acc
      // {
        ${system} = (acc.${system} or { }) // {
          "nixos-${name}" = nixos.config.system.build.toplevel;
        };
      }
    ) { } config.configurations.nixos;
  };
}
