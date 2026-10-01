{
  lib,
  buildNpmPackage,
  importNpmLock,
  source,
}:
let
  projected = import ./project-pi-npm-package.nix { inherit lib; } {
    inherit source;
    extension = "./src/index.ts";
    hostPeers = {
      "@earendil-works/pi-ai" = "*";
      "@earendil-works/pi-coding-agent" = "*";
      "@earendil-works/pi-tui" = "*";
      typebox = "*";
    };
  };
  packageJSON = builtins.toFile "pi-claude-bridge-package.json" (builtins.toJSON projected.package);
  packageLockJSON = builtins.toFile "pi-claude-bridge-package-lock.json" (
    builtins.toJSON projected.packageLock
  );
in
buildNpmPackage {
  pname = "pi-claude-bridge";
  inherit (projected.package) version;
  src = source;

  npmDeps = importNpmLock {
    npmRoot = source;
    inherit (projected) package packageLock;
  };
  npmConfigHook = importNpmLock.npmConfigHook;
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  postPatch = ''
    cp ${packageJSON} package.json
    cp ${packageLockJSON} package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R src node_modules package.json package-lock.json README.md LICENSE "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Claude Code provider for Pi via the Claude Agent SDK";
    homepage = "https://github.com/elidickinson/pi-claude-bridge";
    license = lib.licenses.mit;
  };
}
