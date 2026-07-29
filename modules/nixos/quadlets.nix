{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  flake.modules.nixos.quadlets =
    { config, lib, ... }:
    let
      cfg = config.quadlets;
      media = config.media;
      inherit (lib)
        filterAttrs
        mapAttrs
        mapAttrs'
        mkIf
        mkOption
        nameValuePair
        optional
        optionalAttrs
        types
        ;

      stateDirType = types.submodule {
        options = {
          path = mkOption { type = types.str; };
          mount = mkOption {
            type = types.nullOr types.str;
            default = "/config";
          };
          mode = mkOption {
            type = types.str;
            default = "0750";
          };
          owner = mkOption {
            type = types.str;
            default = media.user;
          };
          group = mkOption {
            type = types.str;
            default = media.group;
          };
        };
      };

      quadletType = types.submodule {
        options = {
          image = mkOption { type = types.str; };
          identity = mkOption {
            type = types.bool;
            default = false;
            description = "Merge the shared linuxserver PUID/PGID/UMASK/TZ identity.";
          };
          user = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          containerConfig = mkOption {
            type = types.attrsOf types.anything;
            default.networks = [ "host" ];
            description = "Additional upstream Quadlet container options.";
          };
          environment = mkOption {
            type = types.attrsOf types.str;
            default = { };
          };
          environmentFiles = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Env files merged into the container, e.g. sops-provided secrets.";
          };
          volumes = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          stateDir = mkOption {
            type = types.nullOr stateDirType;
            default = null;
            description = "Host config directory, created and bind-mounted at stateDir.mount.";
          };
          port = mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Loopback port to expose through the reverse proxy.";
          };
        };
      };

      stateVolume =
        c:
        optional (c.stateDir != null && c.stateDir.mount != null) "${c.stateDir.path}:${c.stateDir.mount}";
    in
    {
      imports = [ nixos.podman ];

      options.quadlets = mkOption {
        type = types.attrsOf quadletType;
        default = { };
        description = "Podman/Quadlet payloads with shared identity and state handling.";
      };

      config = mkIf (cfg != { }) {
        virtualisation.quadlet.containers = mapAttrs (name: c: {
          containerConfig =
            c.containerConfig
            // {
              inherit name;
              inherit (c) image environmentFiles;
              autoUpdate = "registry";
              environments =
                (if c.identity then media.containerEnv else { TZ = config.profile.timeZone; }) // c.environment;
              volumes = stateVolume c ++ c.volumes;
            }
            // optionalAttrs (c.user != null) { inherit (c) user; };
        }) cfg;

        proxy.services = mapAttrs (_: c: { inherit (c) port; }) (filterAttrs (_: c: c.port != null) cfg);

        media.directories = mapAttrs' (
          _: c: nameValuePair c.stateDir.path { inherit (c.stateDir) mode owner group; }
        ) (filterAttrs (_: c: c.stateDir != null) cfg);
      };
    };
}
