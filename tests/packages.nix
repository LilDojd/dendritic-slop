{
  allExtensionPackages,
  catalog,
  config,
  conflictingPiPackage,
  corePackages,
  defaultPackages,
  duplicatePiPackage,
  extensionPackages,
  finalPiPackage,
  herdrAgentStateResource,
  herdrPackage,
  home,
  homeWithProfiles,
  homeWithWebAccess,
  inputs,
  lib,
  optedInPackages,
  piDependencyContractProbe,
  piPackage,
  piResourceProbe,
  pkgs,
  realizedSkills,
  system,
  webAccessPackage,
  ...
}:
{
  declarative-pi-packages =
    assert defaultPackages == [ ];
    assert builtins.elem (toString extensionPackages.ask-user) corePackages;
    assert builtins.elem (toString extensionPackages.pi-mcp-adapter) corePackages;
    assert !home.config.dendriticSlop.extensions.jevons.enable;
    assert catalog.extensions.jevons.profiles == [ ];
    assert catalog.extensions.jevons.capabilities.network;
    assert catalog.extensions.jevons.capabilities.executesCode;
    assert catalog.extensions.jevons.capabilities.readsSecrets;
    assert lib.all (lib.hasPrefix builtins.storeDir) allExtensionPackages;
    assert !lib.any (lib.hasPrefix "npm:") allExtensionPackages;
    assert homeWithProfiles.config.programs.pi.coding-agent.package == piPackage;
    assert finalPiPackage != piPackage;
    assert builtins.elem finalPiPackage homeWithProfiles.config.home.packages;
    assert builtins.elem herdrPackage homeWithProfiles.config.home.packages;
    assert piPackage == inputs.llm-agents.packages.${system}.pi;
    assert herdrPackage == inputs.llm-agents.packages.${system}.herdr;
    assert extensionPackages.superpowers-bootstrap == realizedSkills.repositories.superpowers;
    assert builtins.length duplicatePiPackage.settingsPackages == 1;
    assert !conflictingPiPackage.success;
    pkgs.runCommand "declarative-pi-packages-check"
      {
        extensionRoots = builtins.attrValues extensionPackages;
        profileActivation = homeWithProfiles.activationPackage;
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.jq
        ];
      }
      ''
        set -euo pipefail

        check_package() {
          root="$1"
          extension="$2"
          expected_peers="$3"
          test -d "$root"
          test -f "$root/package.json"
          ${pkgs.jq}/bin/jq -e \
            --arg extension "$extension" \
            '.pi.extensions == [$extension]
             and (.pi.skills // []) == []
             and (.pi.prompts // []) == []
             and (.pi.themes // []) == []' \
            "$root/package.json" >/dev/null
          ${pkgs.nodejs_24}/bin/node ${piDependencyContractProbe} "$root" "$expected_peers"
          (cd "$root" && ${pkgs.nodejs_24}/bin/npm ls --omit=dev --all >/dev/null)
        }

        ask_user_peers=${
          lib.escapeShellArg (
            builtins.toJSON {
              "@earendil-works/pi-coding-agent" = "*";
              "@earendil-works/pi-tui" = "*";
              typebox = "*";
            }
          )
        }
        mcp_adapter_peers=${
          lib.escapeShellArg (
            builtins.toJSON {
              "@earendil-works/pi-ai" = "*";
              "@earendil-works/pi-coding-agent" = "*";
              "@earendil-works/pi-tui" = "*";
              typebox = "*";
            }
          )
        }
        playwright_peers=$(
          ${pkgs.jq}/bin/jq -c '.peerDependencies' ${extensionPackages.pi-playwright.src}/package.json
        )
        web_access_peers="$mcp_adapter_peers"

        check_package ${extensionPackages.jevons} ./pi/extension.ts "$mcp_adapter_peers"
        test ! -e ${extensionPackages.jevons}/.env
        test ! -e ${extensionPackages.jevons}/.jevons
        (cd ${extensionPackages.jevons} && ${pkgs.nodejs_24}/bin/node --input-type=module <<'EOF'
        const sdk = await import("@typesafe-ai/sdk");
        const diff = await import("diff");
        if (typeof sdk.TypeSafeClient !== "function" || typeof diff.parsePatch !== "function") {
          throw new Error("Jevons runtime dependencies are unavailable");
        }
        EOF
        )

        check_package ${extensionPackages.ask-user} ./index.ts "$ask_user_peers"
        check_package ${extensionPackages.pi-mcp-adapter} ./index.ts "$mcp_adapter_peers"
        check_package ${extensionPackages.pi-playwright} ./dist/index.js "$playwright_peers"
        check_package ${extensionPackages.web-access} ./index.ts "$web_access_peers"

        test -d ${extensionPackages.pi-playwright}/node_modules/playwright
        test -d ${extensionPackages.pi-playwright}/node_modules/playwright-core
        test ! -e ${inputs.pi-ask-user}/package-lock.json
        test ! -e ${extensionPackages.ask-user}/package-lock.json
        test ! -e ${extensionPackages.ask-user}/node_modules
        ${pkgs.jq}/bin/jq -e \
          '.pi.extensions == ["./.pi/extensions/superpowers.ts"]
           and (.pi.skills // []) == []
           and (.pi.prompts // []) == []
           and (.pi.themes // []) == []' \
          ${extensionPackages.superpowers-bootstrap}/package.json >/dev/null

        test -d ${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/client
        test -d ${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/ext-apps
        test -d ${extensionPackages.pi-mcp-adapter}/node_modules/@modelcontextprotocol/sdk
        test -d ${extensionPackages.web-access}/node_modules/@mozilla/readability
        ${pkgs.jq}/bin/jq -e \
          '.packages[""].dependencies["@modelcontextprotocol/ext-apps"] == "^1.2.2"
           and .packages["node_modules/@modelcontextprotocol/ext-apps"].version != null
           and .packages["node_modules/@modelcontextprotocol/sdk"].version != null' \
          ${extensionPackages.pi-mcp-adapter}/package-lock.json >/dev/null
        test ! -e ${extensionPackages.web-access}/node_modules/typebox

        # Import mandatory installed dependencies only. Pi host peers are
        # checked as manifest/closure invariants and are never imported alone.
        (cd ${extensionPackages.pi-mcp-adapter} && ${pkgs.nodejs_24}/bin/node --input-type=module <<'EOF'
        await import("@modelcontextprotocol/client");
        await import("@modelcontextprotocol/core");
        await import("@modelcontextprotocol/ext-apps");
        await import("ajv");
        EOF
        )
        (cd ${extensionPackages.web-access} && ${pkgs.nodejs_24}/bin/node --input-type=module <<'EOF'
        await import("@mozilla/readability");
        await import("linkedom");
        await import("unpdf");
        EOF
        )
        test -f ${extensionPackages.superpowers-bootstrap}/skills/using-superpowers/SKILL.md
        test ! -e ${extensionPackages.superpowers-bootstrap}/skills/writing-skills/render-graphs.js

        bootstrap=${extensionPackages.superpowers-bootstrap}/.pi/extensions/superpowers.ts
        ! ${pkgs.gnugrep}/bin/grep -Fq 'resources_discover' "$bootstrap"
        ${pkgs.gnugrep}/bin/grep -Fq 'superpowers:using-superpowers bootstrap for pi' "$bootstrap"
        ${pkgs.gnugrep}/bin/grep -Fq '## Pi tool mapping' "$bootstrap"
        ${pkgs.gnugrep}/bin/grep -Fq 'Pi has native skills' "$bootstrap"
        test -f ${herdrAgentStateResource.realization.source}
        test -x ${piPackage}/bin/pi
        test -x ${herdrPackage}/bin/herdr
        test "$(readlink "$profileActivation/home-path/bin/pi")" = ${lib.escapeShellArg "${finalPiPackage}/bin/pi"}
        test "$(readlink "$profileActivation/home-path/bin/herdr")" = ${lib.escapeShellArg "${herdrPackage}/bin/herdr"}

        agent="$TMPDIR/agent"
        work="$TMPDIR/work"
        marker="$TMPDIR/resources-loaded"
        npm_marker="$TMPDIR/npm-invoked"
        mkdir -p "$agent/extensions" "$work" "$TMPDIR/home" "$TMPDIR/runtime"
        ln -s ${herdrAgentStateResource.realization.source} \
          "$agent/extensions/herdr-agent-state.ts"

        fake_npm="$TMPDIR/npm-must-not-run"
        cat > "$fake_npm" <<EOF
        #!${pkgs.runtimeShell}
        touch "$npm_marker"
        exit 99
        EOF
        chmod +x "$fake_npm"

        ${pkgs.jq}/bin/jq -n \
          --arg npm "$fake_npm" \
          --argjson packages ${lib.escapeShellArg (builtins.toJSON allExtensionPackages)} \
          '{
            packages: $packages,
            npmCommand: [$npm],
            enableInstallTelemetry: false,
            defaultProjectTrust: "never"
          }' > "$agent/settings.json"

        cd "$work"
        set +e
        printf '%s\n' '{"type":"prompt","message":"/dendritic-offline-smoke"}' | \
          env -i \
            HOME="$TMPDIR/home" \
            TMPDIR="$TMPDIR/runtime" \
            PATH=${lib.escapeShellArg (lib.makeBinPath [ pkgs.coreutils ])} \
            PI_CODING_AGENT_DIR="$agent" \
            PI_OFFLINE=1 \
            NPM_CONFIG_OFFLINE=true \
            DENDRITIC_SLOP_SMOKE_MARKER="$marker" \
            ${pkgs.coreutils}/bin/timeout 60 \
            ${lib.getExe piPackage} --offline --mode rpc --no-session --no-context-files \
              -e ${piResourceProbe} > "$TMPDIR/pi.stdout" 2> "$TMPDIR/pi.stderr"
        status=$?
        set -e

        if [ "$status" -ne 0 ]; then
          cat "$TMPDIR/pi.stdout" >&2
          cat "$TMPDIR/pi.stderr" >&2
          exit "$status"
        fi
        test -f "$marker"
        ${pkgs.gnugrep}/bin/grep -Fq '"command":"prompt","success":true' "$TMPDIR/pi.stdout"
        ! ${pkgs.gnugrep}/bin/grep -Eq 'extension_error|Failed to load extension' \
          "$TMPDIR/pi.stdout" "$TMPDIR/pi.stderr"
        test ! -e "$npm_marker"
        test ! -e "$agent/npm"
        test ! -e "$agent/git"

        touch "$out"
      '';
  web-access-opt-in =
    assert builtins.elem webAccessPackage optedInPackages;
    homeWithWebAccess.activationPackage;
}
