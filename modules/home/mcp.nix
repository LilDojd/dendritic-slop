{
  flake.modules.homeManager.mcp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      secrets = config.dendriticSlop.mcpHeaderSecrets;

      headersHelper =
        name: files:
        pkgs.writeShellScript "claude-mcp-${name}-headers" ''
          set -eu
          ${lib.concatStrings (
            lib.mapAttrsToList (variable: file: ''
              IFS= read -r ${variable} < ${lib.escapeShellArg file} || [ -n "''${${variable}:-}" ]
              export ${variable}
            '') files
          )}
          ${lib.getExe pkgs.jq} -n --argjson headers ${
            lib.escapeShellArg (builtins.toJSON config.programs.mcp.servers.${name}.headers)
          } '
            $headers | with_entries(.value |= gsub("\\$\\{(?<name>[A-Za-z_][A-Za-z0-9_]*)\\}"; $ENV[.name]))
          '
        '';
    in
    {
      options.dendriticSlop.mcpHeaderSecrets = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = { };
        example = {
          context7.CONTEXT7_API_KEY = "/run/agenix/context7-api-key";
        };
        description = ''
          Runtime secret files substituted as `''${VARIABLE}` into the headers of
          `programs.mcp.servers.<name>`. Claude Code resolves them with a headers
          helper and Pi receives them as environment variables.
        '';
      };

      config = lib.mkIf (secrets != { }) {
        programs.claude-code.mcpServers = lib.mapAttrs (name: files: {
          type = "http";
          inherit (config.programs.mcp.servers.${name}) url;
          headersHelper = toString (headersHelper name files);
        }) secrets;

        programs.pi.coding-agent.environment = lib.mkMerge (
          lib.mapAttrsToList (_: lib.mapAttrs (_: file: { inherit file; })) secrets
        );
      };
    };
}
