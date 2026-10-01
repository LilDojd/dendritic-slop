{
  lib,
  source,
  stdenvNoCC,
}:
let
  package = builtins.fromJSON (builtins.readFile (source + "/package.json"));
  packageJSON = builtins.toFile "pi-jev-package.json" (
    builtins.toJSON (
      builtins.removeAttrs package [
        "scripts"
        "devDependencies"
      ]
      // {
        peerDependenciesMeta = lib.mapAttrs (_: _: { optional = true; }) package.peerDependencies;
      }
    )
  );
in
assert lib.assertMsg (
  (package.dependencies or { }) == { }
) "Pi Jev gained runtime dependencies; review before packaging";
stdenvNoCC.mkDerivation {
  pname = "pi-jev";
  inherit (package) version;
  src = source;
  dontBuild = true;

  postPatch = ''
    # Project config is read without Pi trust checks; never let it redirect the API key.
    substituteInPlace src/client.ts \
      --replace-fail 'const endpoint = call.endpoint ?? DEFAULT_ENDPOINT;' \
      'if (call.endpoint && call.endpoint !== DEFAULT_ENDPOINT) {
        throw new JevError("Only the TypeSafe endpoint is allowed");
      }
      const endpoint = DEFAULT_ENDPOINT;'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R src README.md LICENSE "$out/"
    cp ${packageJSON} "$out/package.json"

    runHook postInstall
  '';

  meta = {
    description = "TypeSafe Jev decision tool and shadow-mode judges for Pi";
    homepage = "https://github.com/y0usaf/pi-jev";
    license = lib.licenses.mit;
  };
}
