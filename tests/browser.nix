{
  pkgs,
  lib,
  extensionPackages,
  piPackage,
  ...
}:
let
  probe = pkgs.replaceVars ./probes/browser-tools.ts {
    browserRoot = extensionPackages.pi-playwright;
  };
in
{
  pi-playwright-runtime =
    pkgs.runCommand "pi-playwright-runtime-check"
      {
        nativeBuildInputs = [
          pkgs.nodejs_24
          pkgs.jq
        ];
        FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
      }
      ''
        node --input-type=module <<'EOF'
        import assert from "node:assert/strict";
        import { createRequire } from "node:module";
        const require = createRequire("${extensionPackages.pi-playwright}/package.json");
        const version = require("playwright/package.json").version;
        assert.equal(require("./package.json").dependencies.playwright, version);
        assert.equal(require("playwright-core/package.json").version, version);
        assert.equal(version, "${pkgs.playwright-driver.version}");
        EOF

        mkdir -p "$TMPDIR/agent" "$TMPDIR/home" "$TMPDIR/work" "$TMPDIR/runtime"
        cd "$TMPDIR/work"
        {
          printf '%s\n' '{"type":"prompt","message":"/dendritic-browser-smoke"}'
          for attempt in $(seq 1 800); do
            test ! -f "$TMPDIR/done" || break
            sleep 0.1
          done
        } | \
          env -i \
            HOME="$TMPDIR/home" TMPDIR="$TMPDIR/runtime" \
            PATH=${lib.escapeShellArg (lib.makeBinPath [ pkgs.coreutils ])} \
            FONTCONFIG_FILE="$FONTCONFIG_FILE" \
            PI_CODING_AGENT_DIR="$TMPDIR/agent" PI_OFFLINE=1 \
            DENDRITIC_BROWSER_MARKER="$TMPDIR/passed" DENDRITIC_BROWSER_DONE="$TMPDIR/done" \
            ${pkgs.coreutils}/bin/timeout 90 \
            ${lib.getExe piPackage} --offline --mode rpc --no-session --no-context-files \
              -e ${probe} > "$TMPDIR/pi.stdout" 2> "$TMPDIR/pi.stderr" || {
                cat "$TMPDIR/pi.stdout" "$TMPDIR/pi.stderr" >&2
                exit 1
              }
        if ! test -f "$TMPDIR/passed"; then
          cat "$TMPDIR/pi.stdout" "$TMPDIR/pi.stderr" >&2
          exit 1
        fi
        jq -s -e 'any(.[]; .type == "response" and .command == "prompt" and .success == true)' \
          "$TMPDIR/pi.stdout" >/dev/null
        touch "$out"
      '';
}
