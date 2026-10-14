{ lib, stdenvNoCC, runtimeShell, coreutils, python3, src }:

stdenvNoCC.mkDerivation {
  pname = "hunter-performance";
  version = "0.3.0";
  inherit src;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    for command in hunter-mode hunter-fans; do
      install -Dm755 "bin/$command" "$out/bin/$command"
      substituteInPlace "$out/bin/$command" \
        --replace-fail '#!/bin/sh' '#!${runtimeShell}' \
        --replace-fail 'exec cat ' 'exec ${coreutils}/bin/cat '
    done
    install -Dm644 LICENSE "$out/share/licenses/hunter-performance/LICENSE"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ python3 ];
  installCheckPhase = ''
    runHook preInstallCheck
    python3 ${../../checks/test_performance_cli.py} "$out" \
      "${runtimeShell}" "${coreutils}/bin/cat"
    runHook postInstallCheck
  '';

  meta = {
    description = "Read-only performance mode and fan RPM queries for HONOR Hunter FRD-WX9";
    homepage = "https://github.com/lpipp/hunter-linux";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hunter-mode";
  };
}
