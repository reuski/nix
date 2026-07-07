{ ... }:
{
  flake.modules.homeManager.postgres =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.postgresql_18
        (pkgs.lib.hiPrio (
          pkgs.writeShellScriptBin "postgres" ''
            exec ${pkgs.lib.getExe' pkgs.postgresql_18 "postgres"} "$@"
          ''
        ))
        (pkgs.lib.hiPrio (
          pkgs.writeShellScriptBin "initdb" ''
            exec ${pkgs.lib.getExe' pkgs.postgresql_18 "initdb"} "$@"
          ''
        ))
      ];
    };
}
