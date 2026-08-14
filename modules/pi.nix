{ config, inputs, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  piTool = config.dendriticSlopInternal.catalog.tools.pi;
  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.pi.homeModules.default ];

      options.dendriticSlop.targets.pi.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Pi from the pinned llm-agents.nix package.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.pi.enable) {
        programs.pi.coding-agent = {
          enable = true;
          package = piTool.package pkgs;
        };
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.pi.imports = [
    coreModule
    targetModule
  ];
}
