{ config, inputs, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  catalog = config.dendriticSlopInternal.catalog;
  piTool = catalog.tools.pi;
  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      environment = config.programs.pi.coding-agent.environment;
      hasProcessSecrets =
        lib.isAttrs environment
        && lib.any (value: lib.isAttrs value && value ? file) (builtins.attrValues environment);
      unsafeExtensionNames = builtins.attrNames (
        lib.filterAttrs (name: selection: selection.enable && !catalog.extensions.${name}.secretCapable) (
          config.dendriticSlop.extensions or { }
        )
      );
    in
    {
      imports = [ inputs.pi.homeModules.default ];

      options.dendriticSlop.targets.pi.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Pi from the pinned llm-agents.nix package.";
      };

      config = lib.mkIf (config.dendriticSlop.enable && config.dendriticSlop.targets.pi.enable) {
        assertions = [
          {
            assertion =
              config.dendriticSlopInternal.mcp.servers == [ ]
              || config.dendriticSlop.extensions.pi-mcp-adapter.enable;
            message = "Pi reads selected MCP servers through dendriticSlop.extensions.pi-mcp-adapter; enable it or disable the Pi target";
          }
          {
            assertion = !hasProcessSecrets || unsafeExtensionNames == [ ];
            message = ''
              Runtime secrets are exposed to the Pi process, but these selected extensions are not reviewed as secret-capable: ${lib.concatStringsSep ", " unsafeExtensionNames}
            '';
          }
        ];
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
