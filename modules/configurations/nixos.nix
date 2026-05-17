{
  config,
  inputs,
  lib,
  ...
}:
let
  channels = {
    unstable = {
      nixpkgs = inputs.nixpkgs;
      home-manager = inputs.home-manager;
    };
    stable = {
      nixpkgs = inputs.nixpkgs-stable;
      home-manager = inputs.home-manager-stable;
    };
  };
in
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          channel = lib.mkOption {
            type = lib.types.enum (builtins.attrNames channels);
            default = "unstable";
            description = "nixpkgs channel to evaluate this host against.";
          };
          module = lib.mkOption {
            type = lib.types.deferredModule;
            default = { };
            description = "NixOS module for this configuration.";
          };
        };
      }
    );
    default = { };
    description = "NixOS system configurations.";
  };

  config.flake = {
    nixosConfigurations = lib.mapAttrs (
      name: cfg:
      let
        channel = channels.${cfg.channel};
      in
      channel.nixpkgs.lib.nixosSystem {
        modules = [
          channel.home-manager.nixosModules.home-manager
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
