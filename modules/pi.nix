{ config, inputs, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
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
