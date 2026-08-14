{ config, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  inherit (config.flake.lib) mkEnableTarget;

  targetModule =
    { config, lib, ... }:
    {
      options.dendriticSlop.targets.git.enable = mkEnableTarget {
        inherit config lib;
        description = "Add .mcp.json and mcp.json to the global Git ignore list.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.git.enable) {
        programs.git.ignores = [
          ".mcp.json"
          "mcp.json"
        ];
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.git.imports = [
    coreModule
    targetModule
  ];
}
