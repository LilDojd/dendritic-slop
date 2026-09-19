{
  lib,
  buildNpmPackage,
  importNpmLock,
  nodejs_24,
  makeWrapper,
  playwright-driver,
}:
buildNpmPackage {
  pname = "firstmate-tools";
  version = "1.0.0";
  src = ./firstmate-tools;
  nodejs = nodejs_24;
  npmDeps = importNpmLock { npmRoot = ./firstmate-tools; };
  npmConfigHook = importNpmLock.npmConfigHook;
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/bin"
    cp -R node_modules "$out/lib/"
    for tool in chrome-devtools-axi gh-axi quota-axi tasks-axi; do
      makeWrapper ${lib.getExe nodejs_24} "$out/bin/$tool" \
        --add-flags "$out/lib/node_modules/$tool/dist/bin/$tool.js" \
        --prefix PATH : ${lib.makeBinPath [ nodejs_24 ]}
    done
    browser=$(find -L ${playwright-driver.browsers}/chromium_headless_shell-* \
      -type f \( -name chrome-headless-shell -o -name headless_shell \) | head -n 1)
    test -x "$browser"
    # Keep browser startup offline; the upstream fallback runs npx @latest.
    substituteInPlace "$out/lib/node_modules/chrome-devtools-axi/dist/src/bridge.js" \
      --replace-fail 'const args = ["-y", "chrome-devtools-mcp@latest"];' \
        'const args = ["-y", "chrome-devtools-mcp@latest", "--no-performance-crux"];' \
      --replace-fail 'args.push("--isolated");' \
        "args.push(\"--isolated\", \"--executablePath=$browser\");"
    ln -s node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js \
      "$out/lib/chrome-devtools-mcp.js"
    wrapProgram "$out/bin/chrome-devtools-axi" \
      --set CHROME_DEVTOOLS_AXI_MCP_PATH "$out/lib/chrome-devtools-mcp.js" \
      --set CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS 1
    runHook postInstall
  '';
  meta.description = "Pinned Firstmate GitHub, browser, quota, and backlog helpers";
}
