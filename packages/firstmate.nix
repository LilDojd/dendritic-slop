{
  lib,
  stdenvNoCC,
  source,
  bash,
  coreutils,
  curl,
  findutils,
  gawk,
  gh,
  git,
  gnugrep,
  gnused,
  jq,
  nodejs_24,
  procps,
  python3,
  treehouse,
  callPackage,
  makeWrapper,
}:
let
  tools = callPackage ./firstmate-tools.nix { };
  noMistakes = callPackage ./no-mistakes.nix { };
  runtimePath = lib.makeBinPath [
    bash
    coreutils
    curl
    findutils
    gawk
    gh
    git
    gnugrep
    gnused
    jq
    nodejs_24
    procps
    python3
    treehouse
    tools
    noMistakes
  ];
in
stdenvNoCC.mkDerivation {
  pname = "firstmate";
  version = source.shortRev;
  src = source;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];
  passthru = { inherit tools noMistakes treehouse; };
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/firstmate"
    cp -RL bin docs .agents .pi .tasks.toml AGENTS.md README.md CONTRIBUTING.md LICENSE \
      "$out/share/firstmate/"
    patchShebangs "$out/share/firstmate/bin"
    cat >> "$out/share/firstmate/AGENTS.md" <<'EOF'

    ## Nix deployment

    This home is managed by dendritic-slop and Home Manager. Code, bundled skills,
    extensions, and tools are immutable. Do not run runtime installers, hook/skill
    installers, or self-updaters; change the Nix sources and rebuild instead.
    Keep credentials and mutable state in this home's private directories, never
    in the code root. Use Pi for workers and secondmates unless the user explicitly
    requests another harness. Do not use Git/treehouse to mutate Jujutsu checkouts;
    work with separate Git clones, or ask before changing the workflow.
    EOF
    mkdir -p "$out/bin"
    cat > "$out/bin/firstmate" <<'EOF'
    #!${bash}/bin/bash
    set -euo pipefail
    export FM_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/firstmate"
    export FM_BACKEND=herdr FM_PI_HARNESS=pi
    export NM_HOME="$FM_HOME/no-mistakes"
    export NO_MISTAKES_NO_UPDATE_CHECK=1 NO_MISTAKES_TELEMETRY=0
    if [[ ! -f "$FM_HOME/AGENTS.md" ]]; then
      echo 'Enable dendriticSlop.tools.firstmate and activate Home Manager first.' >&2
      exit 1
    fi
    umask 077
    chmod 700 "$FM_HOME"
    mkdir -p "$FM_HOME"/{config,data,state,projects}
    cd "$FM_HOME"
    exec pi "$@"
    EOF
    chmod +x "$out/bin/firstmate"
    wrapProgram "$out/bin/firstmate" \
      --set FM_ROOT_OVERRIDE "$out/share/firstmate" \
      --prefix PATH : ${lib.escapeShellArg runtimePath}
    runHook postInstall
  '';
  meta = {
    description = "Firstmate agent orchestration workspace";
    homepage = "https://github.com/kunchenguid/firstmate";
    license = lib.licenses.mit;
    mainProgram = "firstmate";
    platforms = noMistakes.meta.platforms;
  };
}
