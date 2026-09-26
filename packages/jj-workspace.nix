{
  lib,
  rustPlatform,
  makeWrapper,
  jujutsu,
  source,
}:
rustPlatform.buildRustPackage {
  pname = "herdr-plugin-jj-workspace";
  version = (builtins.fromTOML (builtins.readFile (source + "/Cargo.toml"))).package.version;
  src = source;

  cargoLock.lockFile = source + "/Cargo.lock";
  nativeBuildInputs = [ makeWrapper ];
  postFixup = ''
    wrapProgram "$out/bin/jj-workspace" --prefix PATH : ${lib.makeBinPath [ jujutsu ]}
  '';

  meta = {
    homepage = "https://github.com/NathanFlurry/herdr-plugin-jj-workspace";
    description = "Create Jujutsu workspaces from Herdr";
    license = lib.licenses.mit;
    mainProgram = "jj-workspace";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
