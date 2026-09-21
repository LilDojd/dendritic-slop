{ callPackage }:
callPackage ./narumitw-extension.nix {
  pname = "pi-starship";
  hash = "sha256-PvS+TqX2GvzYGEYqiE7Rk1qMgX6slYsBT6Z2tuD3E78=";
  lockFile = ./locks/pi-starship.json;
  description = "Native Starship-style footer for Pi";
}
