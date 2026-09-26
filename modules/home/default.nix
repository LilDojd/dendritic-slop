{ config, ... }:
{
  flake.modules.homeManager.default.imports = with config.flake.modules.homeManager; [
    claude
    herdr
    mcp
    pi
    rules
    skills
  ];
}
