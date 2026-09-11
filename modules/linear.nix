{ config, ... }:
{
  flake.modules.homeManager.linear.imports = [
    config.flake.modules.homeManager.mcp
  ];
}
