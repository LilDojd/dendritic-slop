{
  lib,
  playwright-driver,
  playwright-test,
  source,
  stdenvNoCC,
}:
let
  package = builtins.fromJSON (builtins.readFile (source + "/package.json"));
  packageJSON = builtins.toFile "pi-playwright-package.json" (
    builtins.toJSON (
      package
      // {
        peerDependenciesMeta = lib.mapAttrs (_: _: { optional = true; }) package.peerDependencies;
      }
    )
  );
  playwrightVersion = package.dependencies.playwright;
in
assert lib.assertMsg (playwright-test.version == playwrightVersion)
  "pi-playwright requires Playwright ${playwrightVersion}, but nixpkgs provides ${playwright-test.version}";
stdenvNoCC.mkDerivation {
  pname = "pi-playwright";
  inherit (package) version;
  src = source;

  dontBuild = true;

  postPatch = ''
    cp ${packageJSON} package.json
    browser_executable=$(find -L ${playwright-driver.browsers}/chromium_headless_shell-* \
      -type f \( -name chrome-headless-shell -o -name headless_shell \) | head -n 1)
    test -x "$browser_executable"

    # Keep model-controlled inputs inside the browser sandbox and screenshot directory.
    substituteInPlace dist/index.js \
      --replace-fail \
        'import { join } from "node:path";' \
        'import { basename, join } from "node:path";' \
      --replace-fail \
        '    executablePath: Type.Optional(Type.String({ description: "Optional path to a local Chrome/Chromium executable" })),' \
        '    // executablePath removed: launching model-selected binaries is unsafe.' \
      --replace-fail \
        '    const executablePath = params?.executablePath;' \
        "    const executablePath = \"$browser_executable\";" \
      --replace-fail \
        '            const page = await getPage(params);' \
        '            const url = new URL(params.url); if (!["http:", "https:"].includes(url.protocol)) throw new Error("Only HTTP(S) URLs are allowed"); const page = await getPage(params);' \
      --replace-fail \
        '            await page.goto(params.url, {' \
        '            await page.goto(url.href, {' \
      --replace-fail \
        '    const filename = params.filename ?? `screenshot-''${Date.now()}.png`;' \
        '    const filename = basename(params.filename ?? `screenshot-''${Date.now()}.png`);'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/node_modules"
    cp -R . "$out/"
    cp -R ${playwright-test}/lib/node_modules/playwright "$out/node_modules/playwright"
    cp -R ${playwright-test}/lib/node_modules/playwright-core "$out/node_modules/playwright-core"

    runHook postInstall
  '';

  meta = {
    description = "Playwright browser automation extension for the Pi coding agent";
    homepage = "https://pi.dev/packages/@lebronj/pi-playwright";
    license = lib.licenses.mit;
  };
}
