{
  fetchurl,
  lib,
  source,
  stdenvNoCC,
}:
let
  package = builtins.fromJSON (builtins.readFile (source + "/package.json"));
  sdk = fetchurl {
    url = "https://registry.npmjs.org/@typesafe-ai/sdk/-/sdk-0.6.0.tgz";
    hash = "sha512-IddX+Q0XM+VagOUZFeP7wZjaO4SHMdvnh2zEBdrZZnXedWI3BNK1lKhMx3ayrkFWvVLbVcUHJy6AVZlY+e6Jaw==";
  };
  diff = fetchurl {
    url = "https://registry.npmjs.org/diff/-/diff-9.0.0.tgz";
    hash = "sha512-svtcdpS8CgJyqAjEQIXdb3OjhFVVYjzGAPO8WGCmRbrml64SPw/jJD4GoE98aR7r25A0XcgrK3F02yw9R/vhQw==";
  };
  packageJSON = builtins.toFile "jevons-package.json" (
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
# These dependency-free tarballs use the integrity hashes in upstream bun.lock.
assert lib.assertMsg (
  package.dependencies == {
    "@typesafe-ai/sdk" = "0.6.0";
    diff = "9.0.0";
  }
) "Jevons runtime dependencies changed; review bun.lock and update the pinned tarballs";
stdenvNoCC.mkDerivation {
  pname = "jevons";
  inherit (package) version;
  src = source;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/node_modules/@typesafe-ai/sdk" "$out/node_modules/diff"
    cp -R pi src README.md LICENSE "$out/"
    cp ${packageJSON} "$out/package.json"
    tar -xzf ${sdk} --strip-components=1 -C "$out/node_modules/@typesafe-ai/sdk"
    tar -xzf ${diff} --strip-components=1 -C "$out/node_modules/diff"

    runHook postInstall
  '';

  meta = {
    description = "Semantic task assistance and verification for Pi";
    homepage = "https://github.com/LilDojd/jevons";
    license = lib.licenses.mit;
  };
}
