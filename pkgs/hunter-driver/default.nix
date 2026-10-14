{ lib, kernel, python3, kmod, src }:

assert lib.assertMsg (lib.versions.majorMinor kernel.version == "6.18")
  "hunter-driver: this package currently supports Linux 6.18 only";

kernel.stdenv.mkDerivation {
  pname = "hunter-driver";
  version = "0.8.0";
  inherit src;
  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ python3 kmod ];
  hardeningDisable = [ "pic" "format" ];
  dontConfigure = true;
  dontStrip = true;
  dontPatchELF = true;
  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    builtinFile="${lib.getOutput "modules" kernel}/lib/modules/${kernel.modDirVersion}/modules.builtin"
    sh ${./check-kernel.sh} "$builtinFile"
    python3 tools/prepare_kernel.py
    make -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" \
      M="$PWD/kernel" W=1 ${lib.escapeShellArgs kernel.commonMakeFlags} modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 kernel/huawei-wmi.ko \
      "$out/lib/modules/${kernel.modDirVersion}/updates/hunter/huawei-wmi.ko"
    mkdir -p "$out/etc/depmod.d"
    printf '%s\n' 'override huawei_wmi * updates/hunter' \
      > "$out/etc/depmod.d/hunter-light.conf"
    install -Dm644 LICENSE "$out/share/licenses/hunter-driver/LICENSE"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    module="$out/lib/modules/${kernel.modDirVersion}/updates/hunter/huawei-wmi.ko"
    test "$(modinfo -F version "$module")" = hunter-0.8.0
    set -- $(modinfo -F vermagic "$module")
    test "$1" = "${kernel.modDirVersion}"
    runHook postInstallCheck
  '';

  passthru = { inherit kernel; };
  meta = {
    description = "Shared Huawei WMI driver with Hunter lighting and read-only performance interfaces for Linux 6.18";
    homepage = "https://github.com/lpipp/hunter-light";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
