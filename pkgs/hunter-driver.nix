{ kernel, kernelModuleMakeFlags, src }:

kernel.stdenv.mkDerivation {
  pname = "hunter-driver";
  version = "0-unstable-${kernel.version}";
  src = "${src}/driver";

  nativeBuildInputs = kernel.moduleBuildDependencies;
  makeFlags = kernelModuleMakeFlags ++ [
    "-C" "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(PWD)"
  ];
  buildFlags = [ "modules" ];

  # modules_install signs the module and emits the .ko.cer the aggregator needs.
  installFlags = [
    "INSTALL_MOD_PATH=${placeholder "out"}"
    "INSTALL_MOD_DIR=updates/hunter"
    "CONFIG_MODULE_COMPRESS_ALL="
  ];
  installTargets = [ "modules_install" ];
  postInstall = ''
    install -Dm644 /dev/stdin $out/etc/depmod.d/hunter.conf <<< 'override huawei_wmi * updates/hunter'
  '';
}
