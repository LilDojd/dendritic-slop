{ inputs, ... }:
{
  flake.modules.homeManager.pi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      packages = config.dendriticSlop.piPackages;
      mcp = config.programs.mcp;
    in
    {
      imports = [ inputs.pi.homeModules.default ];

      options.dendriticSlop.piPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Pi packages written to `programs.pi.coding-agent.settings.packages`, which does not merge across modules.";
      };

      config = {
        programs.pi.coding-agent = {
          package = lib.mkDefault inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
          settings = lib.mkIf (packages != [ ]) { packages = map toString (lib.unique packages); };
        };

        home.file.".pi/agent/mcp.json" =
          lib.mkIf (config.programs.pi.coding-agent.enable && mcp.enable && mcp.servers != { })
            {
              source = (pkgs.formats.json { }).generate "pi-mcp.json" {
                mcpServers = lib.mapAttrs (
                  name: server:
                  lib.hm.mcp.transformMcpServer {
                    inherit server;
                    extraTransforms = [
                      lib.hm.mcp.addType
                      (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; })
                    ];
                  }
                ) mcp.servers;
              };
            };
      };
    };
}
