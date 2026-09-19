{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  releases = {
    x86_64-linux = {
      platform = "linux-amd64";
      sha256 = "1a0dbc50e7ca58dcaf39ecc05619ea55af7a32b5634272f5c3e1915c408bb8be";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      sha256 = "d5dd310a4811f5add117f80ea7a421f6c161a2666f5caca8c16606189c9157b9";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      sha256 = "d4388422e773f7ef5e9c87afb35c1e3be0d572c8c8940f54fe6238e88366f2d3";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "no-mistakes";
  version = "1.75.2";
  src = fetchurl {
    url = "https://github.com/kunchenguid/no-mistakes/releases/download/v${finalAttrs.version}/no-mistakes-v${finalAttrs.version}-${release.platform}.tar.gz";
    inherit (release) sha256;
  };
  sourceRoot = ".";
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 no-mistakes "$out/bin/no-mistakes"
    runHook postInstall
  '';
  meta = {
    description = "Agent-driven code review and validation pipeline";
    homepage = "https://github.com/kunchenguid/no-mistakes";
    license = lib.licenses.mit;
    platforms = builtins.attrNames releases;
    mainProgram = "no-mistakes";
  };
})
