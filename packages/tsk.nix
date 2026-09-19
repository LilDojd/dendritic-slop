{
  lib,
  rustPlatform,
  gitMinimal,
  tsk,
}:
rustPlatform.buildRustPackage {
  pname = "tsk";
  version = (builtins.fromTOML (builtins.readFile (tsk + "/Cargo.toml"))).package.version;
  src = tsk;
  cargoLock.lockFile = tsk + "/Cargo.lock";
  nativeCheckInputs = [ gitMinimal ];

  meta = {
    description = "A terminal task board for you and your agents";
    homepage = "https://github.com/smarzban/tsk";
    license = lib.licenses.mit;
    mainProgram = "tsk";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
