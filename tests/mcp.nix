{
  agentBrowserCommand,
  bridgeFalse,
  bridgeTrue,
  catalog,
  config,
  context7SecretPath,
  duplicateMcpId,
  expectedMergedMcpJson,
  home,
  homeWithContext7,
  homeWithContext7NoSecret,
  homeWithLiteralSecret,
  homeWithMcpCollision,
  homeWithMergedMcps,
  homeWithNixPathSecret,
  homeWithOnlyLinear,
  homeWithRelativeSecret,
  homeWithStoreSecret,
  lib,
  linearMcpJson,
  mcpSecretProbe,
  mergedMcpJson,
  piPackage,
  pkgs,
  ...
}:
{
  mcp-registry =
    assert catalog.mcps.browser.transport.type == "local";
    assert catalog.mcps.context7.transport.type == "remote";
    assert catalog.mcps.browser.serverId == "agent-browser";
    assert catalog.mcps.context7.serverId == "context7";
    assert catalog.mcps.context7.secretFiles.apiKeyFile.environment == "CONTEXT7_API_KEY";
    assert home.options.dendriticSlop.mcps.context7.secrets ? apiKeyFile;
    assert !home.config.dendriticSlop.mcps.context7.enable;
    assert home.config.dendriticSlop.mcps.context7.secrets.apiKeyFile == null;
    assert !(home.config.xdg.configFile ? "mcp/mcp.json");
    assert !(home.options.dendriticSlop ? context7);
    assert !(home.options.dendriticSlop.targets ? context7);
    assert !homeWithRelativeSecret.success;
    assert !homeWithLiteralSecret.success;
    assert !homeWithNixPathSecret.success;
    assert !homeWithStoreSecret.success;
    assert !homeWithMcpCollision.success;
    assert !duplicateMcpId;
    assert homeWithMergedMcps.config.dendriticSlop.mcps.browser.enable;
    assert homeWithMergedMcps.config.dendriticSlop.mcps.context7.enable;
    assert homeWithMergedMcps.config.dendriticSlop.extensions.pi-mcp-adapter.enable;
    assert mergedMcpJson == expectedMergedMcpJson;
    assert
      homeWithContext7.config.programs.pi.coding-agent.environment.CONTEXT7_API_KEY.file
      == context7SecretPath;
    assert !(homeWithContext7NoSecret.config.programs.pi.coding-agent.environment ? CONTEXT7_API_KEY);
    assert !lib.hasInfix context7SecretPath homeWithContext7.config.xdg.configFile."mcp/mcp.json".text;
    assert lib.hasInfix "Bearer \${CONTEXT7_API_KEY}"
      homeWithContext7.config.xdg.configFile."mcp/mcp.json".text;
    assert bridgeTrue.mcps.context7.enable;
    assert bridgeTrue.mcps.context7.secrets.apiKeyFile == context7SecretPath;
    assert !bridgeFalse.mcps.context7.enable;
    assert catalog.extensions.ask-user.secretCapable;
    assert catalog.extensions.herdr-agent-state.secretCapable;
    assert catalog.extensions.jevons.secretCapable;
    assert catalog.extensions.pi-mcp-adapter.secretCapable;
    assert catalog.extensions.pi-playwright.secretCapable;
    assert catalog.extensions.web-access.secretCapable;
    pkgs.runCommand "mcp-registry-check"
      {
        mcpConfig = pkgs.writeText "expected-mcp.json" (
          homeWithMergedMcps.config.xdg.configFile."mcp/mcp.json".text
        );
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.jq
        ];
      }
      ''
        set -euo pipefail

        test "$(jq -r '.mcpServers | keys | join(" ")' "$mcpConfig")" = \
          'agent-browser context7 linear'
        test "$(jq -r '.mcpServers["agent-browser"].command' "$mcpConfig")" = \
          ${lib.escapeShellArg agentBrowserCommand}
        test "$(jq -r '.mcpServers["agent-browser"].args | join(" ")' "$mcpConfig")" = mcp
        test "$(jq -r '.mcpServers.context7.headers.Authorization' "$mcpConfig")" = \
          'Bearer ''${CONTEXT7_API_KEY}'
        ! grep -F ${lib.escapeShellArg context7SecretPath} "$mcpConfig"
        ${agentBrowserCommand} mcp --help > "$TMPDIR/agent-browser-mcp-help"
        ${pkgs.gnugrep}/bin/grep -Fq 'Start an MCP stdio server' \
          "$TMPDIR/agent-browser-mcp-help"

        agent="$TMPDIR/agent"
        work="$TMPDIR/work"
        home_dir="$TMPDIR/home"
        runtime="$TMPDIR/runtime"
        marker="$TMPDIR/adapter-secret-invoked"
        mkdir -p "$agent" "$work" "$home_dir" "$runtime"
        runtime_secret="runtime-$RANDOM-$$"

        cd "$work"
        set +e
        {
          printf '%s\n' '{"type":"prompt","message":"/dendritic-mcp-secret-smoke"}'
          for attempt in $(seq 1 600); do
            [ ! -f "$marker" ] || break
            sleep 0.1
          done
        } | \
          env -i \
            HOME="$home_dir" \
            TMPDIR="$runtime" \
            PATH=${lib.escapeShellArg (lib.makeBinPath [ pkgs.coreutils ])} \
            PI_CODING_AGENT_DIR="$agent" \
            PI_OFFLINE=1 \
            CONTEXT7_API_KEY="$runtime_secret" \
            DENDRITIC_SLOP_MCP_SECRET_MARKER="$marker" \
            ${pkgs.coreutils}/bin/timeout 90 \
            ${lib.getExe piPackage} --offline --mode rpc --no-session --no-context-files \
              -e ${mcpSecretProbe} > "$TMPDIR/pi-mcp.stdout" 2> "$TMPDIR/pi-mcp.stderr"
        status=$?
        set -e

        if [ "$status" -ne 0 ]; then
          cat "$TMPDIR/pi-mcp.stdout" >&2
          cat "$TMPDIR/pi-mcp.stderr" >&2
          exit "$status"
        fi
        if [ ! -f "$marker" ]; then
          cat "$TMPDIR/pi-mcp.stdout" >&2
          cat "$TMPDIR/pi-mcp.stderr" >&2
          echo "MCP secret adapter smoke test did not write its marker" >&2
          exit 1
        fi
        test "$(cat "$marker")" = invoked
        ! grep -F "$runtime_secret" "$mcpConfig" "$marker"
        ! grep -Eq 'extension_error|Failed to load extension' \
          "$TMPDIR/pi-mcp.stdout" "$TMPDIR/pi-mcp.stderr"

        touch "$out"
      '';
  linear-mcp =
    assert !home.config.dendriticSlop.mcps.linear.enable;
    assert !(home.options.dendriticSlop.targets ? linear);
    assert catalog.mcps.linear.transport.auth == "oauth";
    assert catalog.mcps.linear.secretFiles == { };
    assert homeWithOnlyLinear.config.programs.pi.coding-agent.enable;
    assert linearMcpJson == { mcpServers.linear = expectedMergedMcpJson.mcpServers.linear; };
    pkgs.runCommand "linear-mcp-config-check" { nativeBuildInputs = [ pkgs.jq ]; } ''
      jq -e '
        .mcpServers.linear.url == "https://mcp.linear.app/mcp" and
        .mcpServers.linear.auth == "oauth" and
        .mcpServers.linear.lifecycle == "lazy" and
        .mcpServers.context7.url == "https://mcp.context7.com/mcp"
      ' ${homeWithMergedMcps.config.xdg.configFile."mcp/mcp.json".source}
      jq -e '.mcpServers | keys == ["linear"]' \
        ${homeWithOnlyLinear.config.xdg.configFile."mcp/mcp.json".source}
      touch "$out"
    '';
}
