{ config, ... }:
let
  coreModule = config.flake.modules.homeManager.core;
  catalog = config.dendriticSlopInternal.catalog;
  claudeTool = catalog.tools.claude-code;
  herdrSource = config.dendriticSlopInternal.herdrSource;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dendriticSlop;
      claudeDir = config.programs.claude-code.configDir;
      jq = lib.getExe pkgs.jq;

      # Secret-backed headers are resolved by a headers helper at connection
      # time, so neither the secret nor its value enters the Nix store.
      headersHelper =
        contribution:
        pkgs.writeShellScript "claude-mcp-${contribution.serverId}-headers" ''
          set -eu
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: path: ''
              IFS= read -r ${name} < ${lib.escapeShellArg path} || [ -n "''${${name}:-}" ]
              export ${name}
            '') contribution.environmentFiles
          )}
          ${jq} -n --argjson headers ${lib.escapeShellArg (builtins.toJSON contribution.transport.headers)} '
            $headers | with_entries(.value |= gsub("\\$\\{(?<name>[A-Za-z_][A-Za-z0-9_]*)\\}"; $ENV[.name]))
          '
        '';

      renderServer =
        contribution:
        let
          transport = contribution.transport;
        in
        if transport.type == "local" then
          {
            type = "stdio";
            inherit (transport) command;
            args = transport.arguments;
          }
        else
          {
            type = "http";
            inherit (transport) url;
          }
          // (
            if contribution.environmentFiles != { } then
              { headersHelper = toString (headersHelper contribution); }
            else
              lib.optionalAttrs (transport.headers != { }) { inherit (transport) headers; }
          );

      herdrHook = pkgs.writeShellScript "herdr-claude-agent-state" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.python3
          ]
        }
        exec ${pkgs.bash}/bin/sh ${herdrSource}/src/integration/assets/claude/herdr-agent-state.sh "$@"
      '';
      herdrIntegration = cfg.targets.herdr.enable or false;
    in
    {
      options.dendriticSlop.targets.claude.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Claude Code with every selected skill and MCP server.";
      };

      config = lib.mkIf (cfg.enable && cfg.targets.claude.enable) {
        programs.claude-code = {
          enable = true;
          package = claudeTool.package pkgs;
          mcpServers = builtins.listToAttrs (
            map (
              contribution: lib.nameValuePair contribution.serverId (renderServer contribution)
            ) config.dendriticSlopInternal.mcp.servers
          );
          settings = lib.mkMerge [
            # Updates arrive through the flake; the store copy is immutable.
            { env.DISABLE_AUTOUPDATER = "1"; }
            (lib.mkIf herdrIntegration {
              hooks.SessionStart = [
                {
                  matcher = "^(startup|resume|clear|compact|fork)$";
                  hooks = [
                    {
                      type = "command";
                      command = "${herdrHook} session";
                      timeout = 10;
                    }
                  ];
                }
              ];
            })
          ];
          # Herdr reports the integration as installed when it finds its
          # versioned hook here; activation keeps it in sync with the package.
          hooks = lib.mkIf herdrIntegration {
            "herdr-agent-state.sh" = "${herdrSource}/src/integration/assets/claude/herdr-agent-state.sh";
          };
        };

        # Link each skill root whole so its relative references resolve inside
        # the store, and leave the rest of skills/ to Claude Code.
        home.file = lib.mapAttrs' (
          name: target: lib.nameValuePair "${claudeDir}/skills/${name}" { source = target; }
        ) config.dendriticSlopInternal.skills.selected;
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.claude.imports = [
    coreModule
    config.flake.modules.homeManager.mcp
    targetModule
  ];
}
