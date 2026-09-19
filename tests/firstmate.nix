{
  catalog,
  pkgs,
  lib,
  mkHome,
  mkBridgeSystem,
  testUser,
  piPackage,
  herdrPackage,
  ...
}:
let
  package = catalog.tools.firstmate.package pkgs;
  home = mkHome {
    dendriticSlop = {
      targets.pi.enable = true;
      targets.herdr.enable = true;
      tools.firstmate.enable = true;
    };
  };
  workspace = "${home.config.xdg.dataHome}/firstmate";
  host = mkBridgeSystem {
    targets.pi.enable = true;
    targets.herdr.enable = true;
    tools.firstmate.enable = true;
  } { };
in
{
  firstmate-home =
    assert !home.config.home.file."${workspace}/AGENTS.md".force;
    assert !home.config.home.file."${workspace}/.pi/extensions".force;
    assert home.config.programs.pi.coding-agent.extensions == [ ];
    home.activationPackage;

  firstmate-browser = pkgs.runCommand "firstmate-browser-check" { } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export CHROME_DEVTOOLS_AXI_CHROME_ARGS=--no-sandbox
    ${pkgs.coreutils}/bin/timeout 100 ${pkgs.nodejs_24}/bin/node \
      ${./probes/firstmate-browser.mjs} ${package.tools}/bin/chrome-devtools-axi
    touch "$out"
  '';

  firstmate-runtime =
    pkgs.runCommand "firstmate-runtime-check"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
      }
      ''
        export HOME="$TMPDIR/home" XDG_DATA_HOME="$TMPDIR/home/.local/share"
        export PI_CODING_AGENT_DIR="$TMPDIR/agent" PI_OFFLINE=1 NPM_CONFIG_OFFLINE=true
        export FIRSTMATE_SMOKE_MARKER="$TMPDIR/loaded"
        mkdir -p "$XDG_DATA_HOME/firstmate" "$PI_CODING_AGENT_DIR" "$TMPDIR/bin"
        cp -R ${home.activationPackage}/home-files/.local/share/firstmate/. "$XDG_DATA_HOME/firstmate/"
        printf '%s\n' '{"defaultProjectTrust":"never","enableInstallTelemetry":false}' \
          > "$PI_CODING_AGENT_DIR/settings.json"

        # Exercise the launch environment and upstream dependency gates without network or fleet mutations.
        cat > "$TMPDIR/bin/pi" <<'EOF'
        #!${pkgs.runtimeShell}
        set -eu
        test "$PWD" = "$FM_HOME"
        test "$FM_HOME" = "$XDG_DATA_HOME/firstmate"
        test "$FM_BACKEND" = herdr
        test -w "$FM_HOME/state"
        test ! -w "$FM_ROOT_OVERRIDE"
        FM_BOOTSTRAP_DETECT_ONLY=1 FM_BOOTSTRAP_NETWORK=skip bin/fm-bootstrap.sh > "$TMPDIR/bootstrap.log"
        cat "$TMPDIR/bootstrap.log"
        ! grep -E '^(MISSING:|MISSING_MANUAL:|BACKEND_INVALID:)' "$TMPDIR/bootstrap.log"
        exec ${lib.getExe piPackage} "$@"
        EOF
        chmod +x "$TMPDIR/bin/pi"
        export PATH="$TMPDIR/bin:${lib.makeBinPath [ herdrPackage ]}:$PATH"

        set +e
        { printf '%s\n' '{"type":"prompt","message":"/dendritic-firstmate-smoke"}';
          for i in $(seq 1 60); do
            test ! -f "$FIRSTMATE_SMOKE_MARKER" || break
            sleep 1
          done
        } | timeout 90 ${lib.getExe package} --offline --mode rpc --no-session --no-context-files \
          --no-extensions \
          -e ${package}/share/firstmate/.pi/extensions/fm-primary-pi-watch.ts \
          -e ${package}/share/firstmate/.pi/extensions/fm-primary-turnend-guard.ts \
          -e ${package}/share/firstmate/.pi/extensions/fm-branch-supervision.ts \
          -e ${package}/share/firstmate/.pi/extensions/fm-calm.ts \
          -e ${./probes/firstmate.ts} > "$TMPDIR/pi.log" 2>&1
        status=$?
        set -e
        cat "$TMPDIR/pi.log"
        test "$status" = 0
        test -f "$FIRSTMATE_SMOKE_MARKER"
        ! grep -E 'extension_error|Failed to load extension' "$TMPDIR/pi.log"
        test ! -e "$PI_CODING_AGENT_DIR/npm"
        test ! -e "$PI_CODING_AGENT_DIR/git"
        touch "$out"
      '';
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  firstmate-mount-ordering =
    let
      homeDirectory = host.config.users.users.${testUser}.home;
      required =
        lib.toList
          host.config.systemd.services."home-manager-${testUser}".unitConfig.RequiresMountsFor;
      persisted = host.config.environment.persistence."/persistent".users.${testUser}.directories;
    in
    assert lib.all (entry: builtins.elem "${homeDirectory}/${entry.directory}" required) persisted;
    pkgs.runCommand "firstmate-mount-ordering-check" { } ''touch "$out"'';
}
