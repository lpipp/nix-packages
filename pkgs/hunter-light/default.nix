{ lib, stdenvNoCC, runtimeShell, python3, src }:

stdenvNoCC.mkDerivation {
  pname = "hunter-light";
  version = "0.8.0";
  inherit src;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/hunter-light "$out/bin/hunter-light"
    patchShebangs --host "$out/bin/hunter-light"
    install -Dm644 LICENSE "$out/share/licenses/hunter-light/LICENSE"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ python3 ];
  installCheckPhase = ''
    runHook preInstallCheck
    substituteInPlace tests/test_light_cli.py \
      --replace-fail '"/bin/sh"' '"${runtimeShell}"'
    python3 tests/test_light_cli.py
    "$out/bin/hunter-light" --help > /dev/null
    if "$out/bin/hunter-light" logo color:invalid > stdout 2> stderr; then
      echo "Invalid colour was accepted" >&2
      exit 1
    else
      test "$?" -eq 2
      test ! -s stdout
      test -s stderr
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Logo, wind and four-zone keyboard lighting CLI for HONOR Hunter FRD-WX9";
    homepage = "https://github.com/lpipp/hunter-light";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hunter-light";
  };
}
