{ config, ... }:
let
  piModule = config.flake.modules.homeManager.pi;
  inherit (config.flake.lib) mkEnableTarget;

  targetModule =
    { config, lib, ... }:
    let
      cfg = config.dendriticSlop.context7;
      enabled = config.dendriticSlop.enable && config.dendriticSlop.targets.context7.enable;
    in
    {
      options.dendriticSlop = {
        targets.context7.enable = mkEnableTarget {
          inherit config lib;
          description = "Enable the Context7 MCP server.";
        };

        context7.apiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/run/agenix/context7ApiKey";
          description = "Absolute runtime path to a file containing the Context7 API key.";
        };
      };

      config = lib.mkIf enabled {
        assertions = [
          {
            assertion = cfg.apiKeyFile == null || lib.hasPrefix "/" cfg.apiKeyFile;
            message = "dendriticSlop.context7.apiKeyFile must be an absolute runtime path";
          }
        ];

        dendriticSlop.targets.pi.enable = lib.mkDefault true;

        programs.pi.coding-agent.environment = lib.mkIf (cfg.apiKeyFile != null) {
          CONTEXT7_API_KEY.file = cfg.apiKeyFile;
        };

        xdg.configFile."mcp/mcp.json".text = builtins.toJSON {
          mcpServers.context7 = {
            url = "https://mcp.context7.com/mcp";
            lifecycle = "lazy";
          }
          // lib.optionalAttrs (cfg.apiKeyFile != null) {
            headers.Authorization = "Bearer \${CONTEXT7_API_KEY}";
          };
        };
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.context7.imports = [
    piModule
    targetModule
  ];
}
