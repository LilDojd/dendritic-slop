{
  lib,
  runCommand,
  package,
  source,
  executable,
  executablePath,
  supportPaths ? [ ],
}:
let
  manifest = builtins.fromTOML (builtins.readFile (source + "/herdr-plugin.toml"));
in
runCommand "${manifest.id}-${manifest.version}"
  {
    passthru = {
      inherit manifest package;
    };
  }
  ''
    mkdir -p "$out/$(dirname ${lib.escapeShellArg executablePath})"
    cp ${source}/herdr-plugin.toml "$out/herdr-plugin.toml"
    ${lib.concatMapStringsSep "\n" (path: ''
      install -D ${lib.escapeShellArg "${source}/${path}"} "$out/"${lib.escapeShellArg path}
    '') supportPaths}
    ln -s ${lib.getExe' package executable} "$out/"${lib.escapeShellArg executablePath}
  ''
