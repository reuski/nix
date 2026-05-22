{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.homeManager.development =
    { pkgs, ... }:
    {
      imports = [
        homeManager.bun
        homeManager.zed
        homeManager.typescript
        homeManager.go
        homeManager.zig
      ];

      home.packages = with pkgs; [
        delve
        go
        golangci-lint
        govulncheck
        postgresql_18
        redis
        zig
      ];
    };
}
