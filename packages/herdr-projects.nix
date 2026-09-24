{
  lib,
  rustPlatform,
  makeWrapper,
  gitMinimal,
  gh,
  openssh,
  rsync,
  coreutils,
  herdr-projects,
}:
rustPlatform.buildRustPackage {
  pname = "herdr-projects";
  version = (builtins.fromTOML (builtins.readFile (herdr-projects + "/Cargo.toml"))).package.version;
  src = herdr-projects;
  cargoLock.lockFile = herdr-projects + "/Cargo.lock";
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [
    gitMinimal
    rsync
  ];

  postFixup = ''
    wrapProgram "$out/bin/herdr-projects" --prefix PATH : ${
      lib.makeBinPath [
        gitMinimal
        gh
        openssh
        rsync
        coreutils
      ]
    }
  '';

  meta = {
    description = "Coordinate parallel coding agents in Herdr projects";
    homepage = "https://github.com/eliasstravik/herdr-projects";
    license = lib.licenses.mit;
    mainProgram = "herdr-projects";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
