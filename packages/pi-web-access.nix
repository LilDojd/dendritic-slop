{
  jq,
  lib,
  buildNpmPackage,
  source,
}:
buildNpmPackage {
  pname = "pi-web-access";
  version = "0.22.0";
  src = source;

  npmDepsHash = "sha256-MsTCXyg2HCJ0Oa3YV+fRgDPHsA1exP+HCka8t83AIRE=";
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
      | .dependencies |= del(.typebox)
      | .peerDependencies = ((.peerDependencies // {}) + $hostPeers)
      | .peerDependenciesMeta = ((.peerDependenciesMeta // {}) + hostMeta)
    ' package.json > package.json.tmp
    mv package.json.tmp package.json

    # Nix's npm fetcher requires integrity for registry records. Upstream's
    # omitted Pi host peer subtree has six nested Pi records without it.
    ${jq}/bin/jq --argjson hostPeers "$host_peers" '
      def hostMeta: ($hostPeers | with_entries(.value = { optional: true }));
      .packages[""] |= (
        .dependencies |= del(.typebox)
        | .peerDependencies = ((.peerDependencies // {}) + $hostPeers)
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
    description = "Web access extension for the Pi coding agent";
    homepage = "https://github.com/nicobailon/pi-web-access";
    license = lib.licenses.mit;
  };
}
