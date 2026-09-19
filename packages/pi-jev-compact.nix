{
  lib,
  source,
  stdenvNoCC,
}:
let
  package = builtins.fromJSON (builtins.readFile (source + "/package.json"));
  packageJSON = builtins.toFile "pi-jev-compact-package.json" (
    builtins.toJSON (
      builtins.removeAttrs package [
        "devDependencies"
        "scripts"
      ]
      // {
        peerDependenciesMeta = lib.mapAttrs (_: _: { optional = true; }) package.peerDependencies;
      }
    )
  );
in
assert lib.assertMsg (
  package.dependencies == { }
  && (package.optionalDependencies or { }) == { }
  &&
    package.peerDependencies == {
      "@earendil-works/pi-coding-agent" = "*";
      typebox = "*";
    }
) "pi-jev-compact dependencies changed; review upstream before packaging";
stdenvNoCC.mkDerivation {
  pname = "pi-jev-compact";
  inherit (package) version;
  src = source;
  # The fork owns hardening; packaging runs no upstream scripts or dependency install.
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R index.ts src README.md LICENSE "$out/"
    cp ${packageJSON} "$out/package.json"

    runHook postInstall
  '';

  meta = {
    description = "Independent Jev-pruned compaction summaries for Pi";
    homepage = "https://github.com/LilDojd/pi-jev-compact";
    license = lib.licenses.mit;
  };
}
