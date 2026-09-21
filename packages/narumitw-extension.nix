{
  buildNpmPackage,
  fetchurl,
  importNpmLock,
  jq,
  lib,
  pname,
  hash,
  lockFile,
  description,
}:
let
  upstreamLock = builtins.fromJSON (builtins.readFile lockFile);
  kit = "node_modules/@narumitw/pi-tui-kit";
  packageLock = upstreamLock // {
    packages = upstreamLock.packages // {
      ${kit} = upstreamLock.packages.${kit} // {
        peerDependenciesMeta = lib.mapAttrs (_: _: {
          optional = true;
        }) upstreamLock.packages.${kit}.peerDependencies;
      };
    };
  };
  package = packageLock.packages."" // {
    type = "module";
    pi.extensions = [ "./dist/index.ts" ];
  };
in
buildNpmPackage {
  inherit pname;
  inherit (package) version;
  src = fetchurl {
    url = "https://registry.npmjs.org/@narumitw/${pname}/-/${pname}-${package.version}.tgz";
    inherit hash;
  };

  npmDeps = importNpmLock { inherit package packageLock; };
  npmConfigHook = importNpmLock.npmConfigHook;
  npmInstallFlags = [
    "--omit=dev"
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];
  dontNpmBuild = true;

  postPatch = ''
    cp ${builtins.toFile "${pname}-package.json" (builtins.toJSON package)} package.json
    cp ${builtins.toFile "${pname}-package-lock.json" (builtins.toJSON packageLock)} package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    # Pi supplies these peers, including for the shared UI library.
    kit=node_modules/@narumitw/pi-tui-kit/package.json
    ${jq}/bin/jq '.peerDependenciesMeta = (.peerDependencies | with_entries(.value = {optional: true}))' \
      "$kit" > "$kit.tmp"
    mv "$kit.tmp" "$kit"

    mkdir -p "$out"
    cp -R dist node_modules package.json package-lock.json README.md LICENSE "$out/"
    if [ -f NOTICES.md ]; then cp NOTICES.md "$out/"; fi

    runHook postInstall
  '';

  meta = {
    inherit description;
    homepage = "https://github.com/narumiruna/pi-extensions/tree/main/packages/${pname}";
    license = lib.licenses.mit;
  };
}
