{
  jq,
  lib,
  stdenvNoCC,
  source,
}:
stdenvNoCC.mkDerivation {
  pname = "pi-ask-user";
  version = (builtins.fromJSON (builtins.readFile (source + "/package.json"))).version;
  src = source;

  nativeBuildInputs = [ jq ];
  dontBuild = true;

  postPatch = ''
    substituteInPlace index.ts \
      --replace-fail 'from "@sinclair/typebox"' 'from "typebox"'

    host_peers='{
      "@earendil-works/pi-coding-agent": "*",
      "@earendil-works/pi-tui": "*",
      "typebox": "*"
    }'
    ${jq}/bin/jq --argjson hostPeers "$host_peers" '
      def hostMeta: ($hostPeers | with_entries(.value = { optional: true }));
      .pi = { extensions: ["./index.ts"], skills: [] }
      | .peerDependencies = (((.peerDependencies // {}) | del(.["@sinclair/typebox"])) + $hostPeers)
      | .peerDependenciesMeta = hostMeta
    ' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Structured user-question extension for the Pi coding agent";
    homepage = "https://github.com/edlsh/pi-ask-user";
    license = lib.licenses.mit;
  };
}
