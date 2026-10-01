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
      checks.pi-jev = pkgs.runCommand "pi-jev-check" { } ''
        export HOME="$TMPDIR/home"
        export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
        export TYPESAFE_API_KEY="fixture-never-send"
        mkdir -p "$PI_CODING_AGENT_DIR" "$TMPDIR/work"
        echo '{"packages":["${self'.packages.pi-jev}"]}' > "$PI_CODING_AGENT_DIR/settings.json"
        cd "$TMPDIR/work"
        ${self'.packages.pi}/bin/pi --offline --mode rpc --no-session \
          -e ${../resources/tests/pi-jev.js} < /dev/null > smoke.txt 2> errors.txt
        cat errors.txt >&2
        ${pkgs.gnugrep}/bin/grep -Fx 'Pi Jev smoke passed' smoke.txt
        test ! -e "$PI_CODING_AGENT_DIR/npm"
        test ! -e "$PI_CODING_AGENT_DIR/git"

        ${pkgs.nodejs}/bin/node --input-type=module <<'EOF'
        import assert from "node:assert/strict";
        import { askJev, DEFAULT_ENDPOINT } from "${self'.packages.pi-jev}/src/client.ts";
        let calls = 0;
        globalThis.fetch = async (url, options) => {
          calls++;
          assert.equal(url, DEFAULT_ENDPOINT);
          assert.equal(options.headers.Authorization, "Bearer fixture-never-send");
          return new Response(JSON.stringify({
            model: "fixture",
            answers: { safe: { type: "noul", noul: 0.8 } },
          }));
        };
        const call = {
          apiKey: "fixture-never-send", retries: 0, state: "check",
          questions: { safe: { type: "noul", instructions: "Is this safe?" } },
        };
        await assert.rejects(
          askJev({ ...call, endpoint: "https://untrusted.invalid/v1/systemone" }),
          /Only the TypeSafe endpoint is allowed/,
        );
        assert.equal(calls, 0);
        const result = await askJev(call);
        assert.equal(result.answers.safe.noul, 0.8);
        assert.equal(calls, 1);
        EOF
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
                    servers.grafana = {
                      command = pkgs.lib.getExe self'.packages.mcp-grafana;
                      args = [ "--disable-write" ];
                    };
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
                    self'.packages.pi-jev
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
