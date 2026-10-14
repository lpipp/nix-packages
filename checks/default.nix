{ pkgs, nixpkgs, system, source, light, module, overlay,
  performanceSource, performance, performanceModule }:

let
  inherit (pkgs) lib;
  makeSystem = modules: options: nixpkgs.lib.nixosSystem {
    inherit system;
    modules = modules ++ [ options {
      system.stateVersion = "26.05";
    } ];
  };
  disabled = (makeSystem [ module performanceModule ] { }).config;
  lightOnly = (makeSystem [ module ] { hardware.hunter-light.enable = true; }).config;
  performanceOnly = (makeSystem [ performanceModule ] {
    hardware.hunter-performance.enable = true;
  }).config;
  enabled = (makeSystem [ module performanceModule ] {
    hardware.hunter-light.enable = true;
    hardware.hunter-performance.enable = true;
  }).config;
  permissions = import ../modules/permissions.nix { inherit pkgs; };
  moduleTree = enabled.system.modulesTree;
  unsupported = builtins.tryEval ((pkgs.linuxPackages_6_1.callPackage
    ../pkgs/hunter-driver { src = source; }).name);
  overlayPackages = import nixpkgs {
    inherit system;
    overlays = [ overlay ];
  };
  hasPackage = name: config: builtins.any
    (p: (p.pname or "") == name) config.environment.systemPackages;
  hasDriver = config:
    builtins.length config.boot.extraModulePackages == 1
    && builtins.length (builtins.filter (name: name == "huawei_wmi") config.boot.kernelModules) == 1
    && (builtins.head config.boot.extraModulePackages).kernel.outPath == config.boot.kernelPackages.kernel.outPath;
in {
  cli = light;
  performance-cli = performance;

  performance-protocol = pkgs.stdenv.mkDerivation {
    pname = "hunter-performance-protocol-tests";
    version = "0.3.0";
    src = performanceSource;
    dontConfigure = true;
    buildPhase = "make test";
    installPhase = "mkdir -p $out; touch $out/passed";
  };

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
      && !disabled.hardware.hunter-performance.enable
      && !disabled.hardware.hunter-driver.enable
      && disabled.boot.extraModulePackages == [ ]
      && !(builtins.elem "huawei_wmi" disabled.boot.kernelModules)
      && !(lib.hasInfix "hunter-light-permissions" disabled.services.udev.extraRules)
      && !hasPackage "hunter-light" disabled
      && !hasPackage "hunter-performance" disabled
      && hasDriver lightOnly && hasDriver performanceOnly && hasDriver enabled
      && hasPackage "hunter-light" lightOnly
      && !hasPackage "hunter-performance" lightOnly
      && hasPackage "hunter-performance" performanceOnly
      && !hasPackage "hunter-light" performanceOnly
      && !(lib.hasInfix "hunter-light-permissions" performanceOnly.services.udev.extraRules)
      && performanceOnly.system.modulesTree.outPath == moduleTree.outPath
      && lightOnly.system.modulesTree.outPath == moduleTree.outPath
      && lib.hasInfix "hunter-light-permissions" enabled.services.udev.extraRules
      && hasPackage "hunter-light" enabled
      && hasPackage "hunter-performance" enabled
      && overlayPackages.hunter-light.version == "0.8.0"
      && overlayPackages.hunter-performance.version == "0.3.0"
      && !unsupported.success)
    "Hunter NixOS defaults, independent/combined modules, target kernel or overlay checks failed";
    pkgs.runCommand "hunter-module-evaluation" { } ''
      mkdir -p "$out"
      touch "$out/passed"
    '';

} // import ./kernel-matrix.nix {
  inherit pkgs nixpkgs system source module performanceModule;
}
