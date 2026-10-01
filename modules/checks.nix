{
  config,
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, self', ... }:
    {
      checks.pi-claude-bridge = pkgs.runCommand "pi-claude-bridge-check" { } ''
        export HOME="$TMPDIR/home"
        export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
        mkdir -p "$PI_CODING_AGENT_DIR" "$TMPDIR/work"
        echo '{"packages":["${self'.packages.pi-claude-bridge}"]}' > "$PI_CODING_AGENT_DIR/settings.json"
        cd "$TMPDIR/work"
        ${self'.packages.pi}/bin/pi --offline --list-models claude-bridge > models.txt 2> errors.txt
        cat errors.txt >&2
        ${pkgs.gnugrep}/bin/grep -q 'claude-bridge' models.txt
        if ${pkgs.gnugrep}/bin/grep -Eq 'extension_error|Failed to load extension' errors.txt; then
          exit 1
        fi
        test ! -e "$PI_CODING_AGENT_DIR/npm"
        test ! -e "$PI_CODING_AGENT_DIR/git"
        touch "$out"
      '';
      checks.home =
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            config.flake.modules.homeManager.default
            (
              { config, ... }:
              {
                _module.args.osConfig = { };
                home = {
                  username = "slop";
                  homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/slop" else "/home/slop";
                  stateVersion = config.home.version.release;
                };
                programs = {
                  claude-code.enable = true;
                  pi.coding-agent.enable = true;
                  mcp = {
                    enable = true;
                    servers.context7 = {
                      url = "https://mcp.context7.com/mcp";
                      headers.Authorization = "Bearer \${CONTEXT7_API_KEY}";
                    };
                  };
                };
                dendriticSlop = {
                  skills = self.skills;
                  piPackages = [
                    self'.packages.pi-ask-user
                    self'.packages.pi-claude-bridge
                  ];
                  mcpHeaderSecrets.context7.CONTEXT7_API_KEY = "/run/secrets/context7";
                  herdr = {
                    enable = true;
                    plugins = [
                      self'.packages.herdr-plugin-jj-workspace
                      self'.packages.herdr-plugin-tsk
                    ];
                    settings.keys.command = [
                      {
                        key = "prefix+t";
                        type = "plugin_action";
                        command = "herdr-tsk.open-board";
                        description = "Open tsk board";
                      }
                    ];
                  };
                };
              }
            )
          ];
        }).activationPackage;
    };
}
