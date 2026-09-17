{
  lib,
  buildNpmPackage,
  fetchzip,
  importNpmLock,
  nodejs_24,
  source,
}:
let
  projected = import ./project-pi-npm-package.nix { inherit lib; } {
    inherit source;
    hostPeers = {
      "@earendil-works/pi-coding-agent" = "*";
      "@earendil-works/pi-tui" = "*";
    };
  };
  package =
    builtins.removeAttrs projected.package [
      "devDependencies"
      "scripts"
    ]
    // {
      pi = {
        extensions = [ "./extensions/index.js" ];
        skills = [ ];
      };
    };
  # Use the reviewed release's compiled files and only its locked runtime dependencies.
  packageLock = projected.packageLock // {
    version = package.version;
    packages = lib.filterAttrs (_: record: !(record.dev or false)) projected.packageLock.packages // {
      "" = package;
    };
  };
  packageJSON = builtins.toFile "pi-typesafe-package.json" (builtins.toJSON package);
  packageLockJSON = builtins.toFile "pi-typesafe-package-lock.json" (builtins.toJSON packageLock);
in
buildNpmPackage {
  pname = "pi-typesafe";
  inherit (package) version;
  src = fetchzip {
    url = "https://registry.npmjs.org/pi-typesafe/-/pi-typesafe-${package.version}.tgz";
    hash = "sha256-Eke2Rdvgt8DgKK5X6iONwliW1pEIPUYf8Vs+Ov/rzVQ=";
  };
  nodejs = nodejs_24;

  npmDeps = importNpmLock { inherit package packageLock; };
  npmConfigHook = importNpmLock.npmConfigHook;
  npmInstallFlags = [ "--omit=dev" ];
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  postPatch = ''
    cp ${packageJSON} package.json
    cp ${packageLockJSON} package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R dist extensions node_modules package.json package-lock.json README.md LICENSE "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Opt-in TypeSafe structured judgments for the Pi coding agent";
    homepage = "https://github.com/DevMortimer/pi-typesafe";
    license = lib.licenses.mit;
  };
}
