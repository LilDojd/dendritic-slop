{
  lib,
  buildNpmPackage,
  importNpmLock,
  source,
}:
let
  projected = import ./project-pi-npm-package.nix { inherit lib; } {
    inherit source;
    hostPeers = {
      "@earendil-works/pi-ai" = "*";
      "@earendil-works/pi-coding-agent" = "*";
      "@earendil-works/pi-tui" = "*";
      typebox = "*";
    };
    removeDependencies = [ "typebox" ];
  };
  packageJSON = builtins.toFile "pi-web-access-package.json" (builtins.toJSON projected.package);
  packageLockJSON = builtins.toFile "pi-web-access-package-lock.json" (
    builtins.toJSON projected.packageLock
  );
in
buildNpmPackage {
  pname = "pi-web-access";
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
    cp -R . "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Web access extension for the Pi coding agent";
    homepage = "https://github.com/nicobailon/pi-web-access";
    license = lib.licenses.mit;
  };
}
