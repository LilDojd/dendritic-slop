{
  buildNpmPackage,
  esbuild,
  importNpmLock,
  jq,
  lib,
  pname,
  source,
}:
let
  workspace = "packages/${pname}";
  upstream = lib.importJSON (source + "/${workspace}/package.json");
  lock = lib.importJSON (source + "/package-lock.json");
  optionalPeers = peers: lib.mapAttrs (_: _: { optional = true; }) peers;
  package =
    builtins.removeAttrs upstream [
      "devDependencies"
      "scripts"
      "files"
    ]
    // {
      pi.extensions = [ "./dist/index.ts" ];
      peerDependenciesMeta = optionalPeers upstream.peerDependencies;
    };

  # Follow Node's nearest node_modules lookup in the upstream workspace lock.
  resolve =
    from: name:
    let
      path = lib.optionalString (from != "") "${from}/" + "node_modules/${name}";
    in
    if builtins.hasAttr path lock.packages then
      path
    else if from == "" then
      throw "Missing locked runtime dependency: ${name}"
    else
      resolve (
        let
          parent = builtins.dirOf from;
        in
        if parent == "." then "" else parent
      ) name;
  dependencies = record: (record.dependencies or { }) // (record.optionalDependencies or { });
  closure = builtins.genericClosure {
    startSet = map (name: { key = resolve workspace name; }) (
      builtins.attrNames (dependencies package)
    );
    operator =
      { key }:
      map (name: { key = resolve key name; }) (builtins.attrNames (dependencies lock.packages.${key}));
  };
  records = map (
    { key }:
    let
      record = lock.packages.${key};
    in
    assert lib.assertMsg (
      !(record.link or false) && record ? integrity
    ) "${pname}: review non-registry runtime dependency ${key}";
    assert lib.assertMsg (lib.all (name: builtins.hasAttr name upstream.peerDependencies) (
      builtins.attrNames (record.peerDependencies or { })
    )) "${pname}: review new non-host peer dependencies in ${key}";
    lib.nameValuePair (lib.removePrefix "${workspace}/" key) (
      record
      // {
        dev = false;
        peerDependenciesMeta = optionalPeers (record.peerDependencies or { });
      }
    )
  ) closure;
  runtimeRecords = builtins.listToAttrs records;
  packageLock = {
    inherit (lock) lockfileVersion;
    inherit (package) name version;
    requires = true;
    packages = runtimeRecords // {
      "" = package;
    };
  };
in
assert lib.assertMsg (
  builtins.length records == builtins.length (builtins.attrNames runtimeRecords)
) "${pname}: workspace and hoisted dependencies collide; review upstream lock layout";
buildNpmPackage {
  inherit pname;
  inherit (package) version;
  src = source;

  npmDeps = importNpmLock { inherit package packageLock; };
  npmConfigHook = importNpmLock.npmConfigHook;
  npmInstallFlags = [
    "--omit=dev"
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];
  nativeBuildInputs = [ esbuild ];
  dontNpmBuild = true;

  postPatch = ''
    cp ${builtins.toFile "${pname}-package.json" (builtins.toJSON package)} package.json
    cp ${builtins.toFile "${pname}-package-lock.json" (builtins.toJSON packageLock)} package-lock.json
  '';

  buildPhase = ''
    runHook preBuild
    esbuild ${workspace}/src/index.ts --bundle --packages=external --platform=node \
      --format=esm --target=es2022 --splitting --out-extension:.js=.ts --outdir=dist
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Pi supplies host peers for the extension and its runtime libraries.
    for manifest in ${
      lib.concatMapStringsSep " " (entry: lib.escapeShellArg "${entry.name}/package.json") records
    }; do
      ${jq}/bin/jq '.peerDependenciesMeta = ((.peerDependencies // {}) | with_entries(.value = {optional: true}))' \
        "$manifest" > "$manifest.tmp"
      mv "$manifest.tmp" "$manifest"
    done

    mkdir -p "$out"
    cp -R dist node_modules package.json package-lock.json "$out/"
    cp ${workspace}/README.md ${workspace}/LICENSE "$out/"
    if [ -f ${workspace}/NOTICES.md ]; then cp ${workspace}/NOTICES.md "$out/"; fi

    runHook postInstall
  '';

  meta = {
    inherit (upstream) description;
    homepage = "https://github.com/narumiruna/pi-extensions/tree/main/${workspace}";
    license = lib.licenses.mit;
  };
}
