{ stdenv, src }:

stdenv.mkDerivation {
  pname = "hunter";
  version = "0-unstable";
  inherit src;

  buildFlags = [ "cli" ];
  doCheck = true;
  checkTarget = "test";
  installPhase = "install -Dm755 hunter $out/bin/hunter";

  meta.mainProgram = "hunter";
}
