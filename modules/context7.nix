{ config, ... }:
{
  # Keep the feature module as a focused import surface. Context7 itself is a
  # catalog leaf selected through dendriticSlop.mcps.context7; this module does
  # not define legacy target or secret aliases.
  flake.modules.homeManager.context7.imports = [
    config.flake.modules.homeManager.mcp
  ];
}
