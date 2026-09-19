{
  fetchzip,
  jq,
  lib,
  playwright-driver,
  playwright-test,
  stdenvNoCC,
}:
assert lib.assertMsg (playwright-test.version == playwright-driver.version)
  "pi-playwright client ${playwright-test.version} does not match browser driver ${playwright-driver.version}";
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-playwright";
  version = "0.0.1";
  src = fetchzip {
    url = "https://registry.npmjs.org/@lebronj/pi-playwright/-/pi-playwright-${finalAttrs.version}.tgz";
    hash = "sha256-DjR9bHFjsdxB0WyDFa5HOHYTEf03gWJgt4gfuYbvOHE=";
  };

  nativeBuildInputs = [ jq ];
  patches = [ ./patches/pi-playwright.patch ];
  dontBuild = true;

  postPatch = ''
    # Nix supplies the JS client and matching browsers; Pi supplies host peers.
    jq --arg version "${playwright-test.version}" '
      .dependencies.playwright = $version
      | .peerDependenciesMeta = (.peerDependencies | map_values({ optional: true }))
    ' package.json > package.json.tmp
    mv package.json.tmp package.json

    browser_executable=$(find -L ${playwright-driver.browsers}/chromium_headless_shell-* \
      -type f \( -name chrome-headless-shell -o -name headless_shell \) | head -n 1)
    test -x "$browser_executable"
    substituteInPlace dist/index.js \
      --replace-fail '@browserExecutable@' "$browser_executable"
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
})
