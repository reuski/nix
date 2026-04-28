{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "zjstatus";
  version = "v0.23.0";

  src = fetchurl {
    url = "https://github.com/dj95/zjstatus/releases/download/v${version}/zjstatus.wasm";
    hash = "sha256-4AaQEiNSQjnbYYAh5MxdF/gtxL+uVDKJW6QfA/E4Yf8=";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/share/zellij/plugins
    cp $src $out/share/zellij/plugins/zjstatus.wasm
  '';

  meta = {
    description = "A status bar plugin for zellij";
    homepage = "https://github.com/dj95/zjstatus";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
