{ inputs, ... }:
{
  flake.modules.homeManager.herdr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dendriticSlop.herdr;
      toml = pkgs.formats.toml { };
      herdr = lib.getExe cfg.package;
      assets = "${cfg.package.src}/src/integration/assets";
      agents =
        lib.optional config.programs.pi.coding-agent.enable "pi"
        ++ lib.optional config.programs.claude-code.enable "claude";
      rules = ''

        # Herdr agent selection

        When working in Herdr, spawn only agents from the following list unless the user explicitly requests another agent kind: ${lib.concatStringsSep ", " agents}.
      '';

      registryEntry = plugin: {
        plugin_id = plugin.manifest.id;
        name = plugin.manifest.name or plugin.manifest.id;
        inherit (plugin.manifest) version;
        manifest_path = "${plugin}/herdr-plugin.toml";
        plugin_root = "${plugin}";
        enabled = true;
      };

      checkedConfig =
        pkgs.runCommand "herdr-config.toml" { config = toml.generate "herdr-config.toml" cfg.settings; }
          ''
            cp "$config" "$out"
            HOME="$TMPDIR" HERDR_CONFIG_PATH="$out" ${herdr} config check
          '';
    in
    {
      options.dendriticSlop.herdr = {
        enable = lib.mkEnableOption "Herdr and its agent integrations";
        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
          defaultText = lib.literalExpression "inputs.llm-agents.packages.\${system}.herdr";
          description = "Herdr package, whose source also provides the skill and agent integrations.";
        };
        plugins = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Plugin roots built with `packages/herdr-plugin.nix`, registered in `plugins.json`.";
        };
        settings = lib.mkOption {
          inherit (toml) type;
          default = { };
          description = "Contents of Herdr's `config.toml`.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            home.packages = [ cfg.package ] ++ map (plugin: plugin.package) cfg.plugins;
            dendriticSlop.skills.herdr = "${cfg.package.src}/skills/herdr";
            programs.claude-code.context = rules;
            programs.pi.coding-agent.rules = rules;
            xdg.configFile = {
              "herdr/config.toml" = lib.mkIf (cfg.settings != { }) {
                source = checkedConfig;
                onChange = "${herdr} server reload-config >/dev/null 2>&1 || true";
              };
              "herdr/plugins.json" = lib.mkIf (cfg.plugins != [ ]) {
                text = builtins.toJSON (map registryEntry cfg.plugins);
              };
            };
          }
          (lib.mkIf config.programs.pi.coding-agent.enable {
            programs.pi.coding-agent.extensions = [ "${assets}/pi/herdr-agent-state.ts" ];
          })
          (lib.mkIf config.programs.claude-code.enable {
            programs.claude-code = {
              hooks."herdr-agent-state.sh" = "${assets}/claude/herdr-agent-state.sh";
              settings.hooks.SessionStart = [
                {
                  matcher = "^(startup|resume|clear|compact|fork)$";
                  hooks = [
                    {
                      type = "command";
                      command = "${pkgs.writeShellScript "herdr-claude-agent-state" ''
                        export PATH=${
                          lib.makeBinPath [
                            pkgs.coreutils
                            pkgs.python3
                          ]
                        }
                        exec ${pkgs.bash}/bin/sh ${assets}/claude/herdr-agent-state.sh "$@"
                      ''} session";
                      timeout = 10;
                    }
                  ];
                }
              ];
            };
          })
        ]
      );
    };
}
