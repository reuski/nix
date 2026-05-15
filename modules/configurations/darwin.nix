{
  config,
  inputs,
  lib,
  ...
}:
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
          default = { };
          description = "nix-darwin module for this configuration.";
        };
      }
    );
    default = { };
    description = "nix-darwin system configurations.";
  };

  config.flake = {
    darwinConfigurations = lib.mapAttrs (
      _name: cfg:
      inputs.darwin.lib.darwinSystem {
        modules = [
          inputs.home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
            };
          }
          cfg.module
        ];
      }
    ) config.configurations.darwin;

    checks = lib.foldlAttrs (
      acc: name: _cfg:
      let
        darwin = config.flake.darwinConfigurations.${name};
        inherit (darwin.config.nixpkgs.hostPlatform) system;
      in
      acc
      // {
        ${system} = (acc.${system} or { }) // {
          "darwin-${name}" = darwin.config.system.build.toplevel;
        };
      }
    ) { } config.configurations.darwin;
  };
}
