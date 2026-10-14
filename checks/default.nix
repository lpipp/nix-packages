{ pkgs, nixpkgs, system, source, light, driver, module, overlay }:

let
  inherit (pkgs) lib;
  makeSystem = enabled: nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [ module {
      hardware.hunter-light.enable = enabled;
      system.stateVersion = "26.05";
    } ];
  };
  disabled = (makeSystem false).config;
  enabled = (makeSystem true).config;
  permissions = import ../modules/permissions.nix { inherit pkgs; };
  moduleTree = enabled.system.modulesTree;
  kernel = enabled.boot.kernelPackages.kernel;
  selectedDriver = builtins.head enabled.boot.extraModulePackages;
  unsupported = builtins.tryEval ((pkgs.linuxPackages_6_12.callPackage
    ../pkgs/hunter-driver { src = source; }).name);
  overlayPackage = (import nixpkgs {
    inherit system;
    overlays = [ overlay ];
  }).hunter-light;
in {
  cli = light;
  driver = driver;

  protocol = pkgs.stdenv.mkDerivation {
    pname = "hunter-light-protocol-tests";
    version = "0.8.0";
    src = source;
    nativeBuildInputs = [ pkgs.python3 ];
    dontConfigure = true;
    buildPhase = ''
      make test-driver
      substituteInPlace tests/test_light_cli.py \
        --replace-fail '"/bin/sh"' '"${pkgs.runtimeShell}"'
      python3 tests/test_light_cli.py
      python3 tests/test_light_validation.py
      python3 tests/test_logo_effect_validation.py
      python3 tests/test_wind_effect_validation.py
      python3 tests/test_keyboard_effect_validation.py
    '';
    installPhase = "mkdir -p $out; touch $out/passed";
  };

  permissions = pkgs.runCommand "hunter-light-permissions-tests" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    python3 ${./test_permissions.py} ${permissions}
    mkdir -p "$out"
    touch "$out/passed"
  '';

  kernel-guard = pkgs.runCommand "hunter-driver-kernel-guard-tests" { } ''
    printf '%s\n' kernel/drivers/acpi/battery.ko > modular
    sh ${../pkgs/hunter-driver/check-kernel.sh} modular
    printf '%s\n' kernel/drivers/platform/x86/huawei-wmi.ko > builtin
    if sh ${../pkgs/hunter-driver/check-kernel.sh} builtin > stdout 2> stderr; then
      echo "Built-in Huawei WMI was accepted" >&2; exit 1
    else
      test "$?" -eq 1
      grep -F CONFIG_HUAWEI_WMI=y stderr
    fi
    if sh ${../pkgs/hunter-driver/check-kernel.sh} missing > stdout 2> stderr; then
      echo "Missing kernel metadata was accepted" >&2; exit 1
    else
      test "$?" -eq 1
    fi
    mkdir -p "$out"
    touch "$out/passed"
  '';

  module = assert lib.assertMsg
    (!disabled.hardware.hunter-light.enable
      && disabled.boot.extraModulePackages == [ ]
      && !(builtins.elem "huawei_wmi" disabled.boot.kernelModules)
      && !(lib.hasInfix "hunter-light-permissions" disabled.services.udev.extraRules)
      && builtins.elem "huawei_wmi" enabled.boot.kernelModules
      && builtins.length enabled.boot.extraModulePackages == 1
      && (builtins.head enabled.boot.extraModulePackages).kernel.outPath == kernel.outPath
      && lib.hasInfix "hunter-light-permissions" enabled.services.udev.extraRules
      && builtins.any (p: (p.pname or "") == "hunter-light") enabled.environment.systemPackages
      && overlayPackage.version == "0.8.0"
      && !unsupported.success)
    "hunter-light NixOS defaults, target kernel or overlay checks failed";
    pkgs.runCommand "hunter-light-module-evaluation" { } ''
      mkdir -p "$out"
      touch "$out/passed"
    '';

  module-selection = pkgs.runCommand "hunter-light-module-selection" {
    nativeBuildInputs = [ pkgs.kmod ];
  } ''
    tree=${moduleTree}
    selected=$(modinfo -b "$tree" -k ${kernel.modDirVersion} -n huawei_wmi)
    expected=${selectedDriver}/lib/modules/${kernel.modDirVersion}/updates/hunter/huawei-wmi.ko
    test "$(readlink -f "$selected")" = "$expected"
    test "$(modinfo -F version "$selected")" = hunter-0.8.0
    modprobe -d "$tree" -S ${kernel.modDirVersion} --show-depends huawei_wmi > dependencies
    grep -F '/updates/hunter/huawei-wmi.ko' dependencies
    mkdir -p "$out"
    cp dependencies "$out/"
    printf '%s\n' "$selected" > "$out/selected-module"
  '';
}
