{
  config,
  inputs,
  lib,
  ...
}:
let
  classes = {
    nixos = {
      build = inputs.nixpkgs.lib.nixosSystem;
      hmModule = inputs.home-manager.nixosModules.home-manager;
      extra = name: { networking.hostName = lib.mkDefault name; };
    };
    darwin = {
      build = inputs.darwin.lib.darwinSystem;
      hmModule = inputs.home-manager.darwinModules.home-manager;
      extra = _name: { };
    };
  };

  mkConfigurations =
    class: spec:
    lib.mapAttrs (
      name: cfg:
      spec.build {
        modules = [
          spec.hmModule
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
            };
          }
          (spec.extra name)
          cfg.module
        ];
      }
    ) config.configurations.${class};

  mkChecks =
    class:
    lib.foldlAttrs (
      acc: name: _cfg:
      let
        built = config.flake."${class}Configurations".${name};
        inherit (built.config.nixpkgs.hostPlatform) system;
      in
      acc
      // {
        ${system} = (acc.${system} or { }) // {
          "${class}-${name}" = built.config.system.build.toplevel;
        };
      }
    ) { } config.configurations.${class};
in
{
  options.configurations = lib.mapAttrs (
    class: _:
    lib.mkOption {
      type = lib.types.lazyAttrsOf (
        lib.types.submodule {
          options.module = lib.mkOption {
            type = lib.types.deferredModule;
            default = { };
            description = "${class} module for this configuration.";
          };
        }
      );
      default = { };
      description = "${class} system configurations.";
    }
  ) classes;

  config.flake = {
    nixosConfigurations = mkConfigurations "nixos" classes.nixos;
    darwinConfigurations = mkConfigurations "darwin" classes.darwin;

    checks = lib.recursiveUpdate (mkChecks "nixos") (mkChecks "darwin");
  };
}
