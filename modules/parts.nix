{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-parts.flakeModules.touchup
  ];

  touchup.attr.modules.enable = false;
}
