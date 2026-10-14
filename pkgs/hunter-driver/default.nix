{ lib, kernel, python3, kmod, src }:

let
  supportedKernels = import ./supported-kernels.nix;
in
assert lib.assertMsg (builtins.elem (lib.versions.majorMinor kernel.version) supportedKernels)
  "hunter-driver: supported Linux series: ${lib.concatStringsSep ", " supportedKernels}";

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
    ${lib.optionalString (lib.versions.majorMinor kernel.version == "6.6") ''
      # Adapt the platform removal field and integer WMI notification API.
      # Apply after generating the driver; OEM transactions stay unchanged.
      patch --fuzz=0 -p1 < ${./linux-6.6.patch}
    ''}
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
    description = "Shared Huawei WMI driver with Hunter lighting and read-only performance interfaces";
    homepage = "https://github.com/lpipp/hunter-light";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
