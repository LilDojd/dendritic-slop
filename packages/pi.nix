{ lib, pi }:
pi.overrideAttrs (old: {
  # The npm tarball ships dist/, but Bun's worker URL uses the source layout.
  preInstall = ''
    mkdir -p src/extensions/codemode
    echo 'import "../../../dist/extensions/codemode/worker.js";' > src/extensions/codemode/worker.ts
  ''
  +
    lib.replaceStrings
      [ "bun build --compile ./dist/bun/cli.js" ]
      [ "bun build --compile ./dist/bun/cli.js ./src/extensions/codemode/worker.ts" ]
      old.preInstall;

  postInstallCheck = old.postInstallCheck + ''
    PI_CODING_AGENT_DIR="$TMPDIR/pi-codemode-smoke" "$out/bin/pi" \
      --offline --no-extensions --no-skills --no-context-files --no-themes \
      --no-prompt-templates --extension ${../resources/tests/pi-codemode.js} \
      --no-session --mode rpc < /dev/null > "$TMPDIR/pi-codemode.log"
    grep -Fx 'Pi codemode smoke passed' "$TMPDIR/pi-codemode.log"
  '';
})
