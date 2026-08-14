{
  jq,
  lib,
  buildNpmPackage,
  source,
}:
buildNpmPackage {
  pname = "pi-mcp-adapter";
  version = "2.22.0";
  src = source;

  npmDepsHash = "sha256-muh64Y12EVJ/zMJItn3YR4auta+ZEYqTBBx+ez+TL7c=";
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  nativeBuildInputs = [ jq ];

  postPatch = ''
    host_peers='{
      "@earendil-works/pi-ai": "*",
      "@earendil-works/pi-coding-agent": "*",
      "@earendil-works/pi-tui": "*",
      "typebox": "*"
    }'

    ${jq}/bin/jq --argjson hostPeers "$host_peers" '
      def hostMeta: ($hostPeers | with_entries(.value = { optional: true }));
      .pi = { extensions: ["./index.ts"], skills: [] }
      | .peerDependencies = ((.peerDependencies // {}) + $hostPeers)
      | .peerDependenciesMeta = ((.peerDependenciesMeta // {}) + hostMeta)
    ' package.json > package.json.tmp
    mv package.json.tmp package.json

    # Nix's npm fetcher requires integrity for registry records. Upstream's
    # omitted Pi host dev subtree has six nested Pi records without it.
    ${jq}/bin/jq --argjson hostPeers "$host_peers" '
      def hostMeta: ($hostPeers | with_entries(.value = { optional: true }));
      .packages[""] |= (
        .peerDependencies = ((.peerDependencies // {}) + $hostPeers)
        | .peerDependenciesMeta = ((.peerDependenciesMeta // {}) + hostMeta)
      )
      | .packages |= with_entries(
        select(
          ((.key | startswith("node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/"))
            and ((.value.integrity // "") == ""))
          | not
        )
      )
    ' package-lock.json > package-lock.json.tmp
    mv package-lock.json.tmp package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"

    runHook postInstall
  '';

  meta = {
    description = "MCP adapter extension for the Pi coding agent";
    homepage = "https://github.com/nicobailon/pi-mcp-adapter";
    license = lib.licenses.mit;
  };
}
