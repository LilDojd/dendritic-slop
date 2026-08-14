{ config, inputs, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  inherit (config.flake.lib) mkEnableTarget;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.pi.homeModules.default ];

      options.dendriticSlop.targets.pi.enable = mkEnableTarget {
        inherit config lib;
        description = "Enable Pi and its pinned MCP adapter.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.pi.enable) {
        programs.pi.coding-agent = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
          settings.packages = [ "npm:pi-mcp-adapter@2.21.2" ];
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
