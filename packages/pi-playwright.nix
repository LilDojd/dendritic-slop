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
        # Nix supplies the JS client and matching browsers, not upstream's npm pin.
        dependencies = package.dependencies // {
          playwright = playwright-test.version;
        };
        peerDependenciesMeta = lib.mapAttrs (_: _: { optional = true; }) package.peerDependencies;
      }
    )
  );
in
assert lib.assertMsg (playwright-test.version == playwright-driver.version)
  "pi-playwright client ${playwright-test.version} does not match browser driver ${playwright-driver.version}";
stdenvNoCC.mkDerivation {
  pname = "pi-playwright";
  inherit (package) version;
  src = source;

  patches = [ ./patches/pi-playwright.patch ];
  dontBuild = true;

  postPatch = ''
    cp ${packageJSON} package.json
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
}
