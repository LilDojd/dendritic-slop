{ callPackage }:
callPackage ./narumitw-extension.nix {
  pname = "pi-goal";
  hash = "sha256-7gXemZ3EoL42Fl5vj39y3hTKymwYRJZbj1aC9FkpBG8=";
  lockFile = ./locks/pi-goal.json;
  description = "Autonomous single-objective goals for Pi";
}
