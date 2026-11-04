{ pkgs, nixpkgs, system, source, module, performanceModule }:

let
  inherit (pkgs) lib;
  # The stable archive predates 7.3; the pinned unstable CI job covers it.
  series = builtins.filter
    (version: builtins.hasAttr "linuxPackages_${lib.replaceStrings [ "." ] [ "_" ] version}" pkgs)
    (import ../pkgs/hunter-driver/supported-kernels.nix);
  checksFor = version:
    let
      suffix = lib.replaceStrings [ "." ] [ "_" ] version;
      kernelPackages = pkgs."linuxPackages_${suffix}";
      config = (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ module performanceModule {
          boot.kernelPackages = kernelPackages;
          hardware.hunter-light.enable = true;
          hardware.hunter-performance.enable = true;
          system.stateVersion = "26.05";
        } ];
      }).config;
      kernel = config.boot.kernelPackages.kernel;
      driver = builtins.head config.boot.extraModulePackages;
      tree = config.system.modulesTree;
      usesModuleCertificates = builtins.any
        (flag: lib.hasPrefix "cmd_sign=" flag && lib.hasInfix "kmodigest" flag)
        kernelPackages.kernelModuleMakeFlags;
    in {
      "driver-${suffix}" = kernelPackages.callPackage ../pkgs/hunter-driver { src = source; };

      "module-selection-${suffix}" = assert lib.assertMsg
        (builtins.length config.boot.extraModulePackages == 1
          && builtins.length (builtins.filter (n: n == "huawei_wmi") config.boot.kernelModules) == 1
          && driver.kernel.outPath == kernel.outPath
          && lib.versions.majorMinor kernel.version == version)
        "Hunter modules must share one driver matching Linux ${version}";
        pkgs.runCommand "hunter-module-selection-${version}" {
          nativeBuildInputs = [ pkgs.kmod pkgs.python3 ];
        } ''
          tree=${tree}
          selected=$(modinfo -b "$tree" -k ${kernel.modDirVersion} -n huawei_wmi)
          expected=${driver}/lib/modules/${kernel.modDirVersion}/updates/hunter/huawei-wmi.ko
          test "$(readlink -f "$selected")" = "$expected"
          test "$(modinfo -F version "$selected")" = hunter-0.8.0
          set -- $(modinfo -F vermagic "$selected")
          test "$1" = ${lib.escapeShellArg kernel.modDirVersion}
          ${lib.optionalString usesModuleCertificates ''
            test -s "$expected.cer"
            test -s "$tree/lib/modules/${kernel.modDirVersion}/modules.cer"
            test "$(modinfo -F sig_id "$selected")" = 'PKCS#7'
            python3 - "$expected.cer" "$tree/lib/modules/${kernel.modDirVersion}/modules.cer" <<'PY'
          import pathlib
          import sys
          certificate, bundle = (pathlib.Path(p).read_bytes() for p in sys.argv[1:])
          assert certificate and certificate in bundle, "Hunter certificate missing from modules.cer"
          PY
          ''}
          modprobe -d "$tree" -S ${kernel.modDirVersion} --show-depends huawei_wmi > dependencies
          grep -F '/updates/hunter/huawei-wmi.ko' dependencies
          mkdir -p "$out"
          cp dependencies "$out/"
          printf '%s\n' "$selected" > "$out/selected-module"
          printf '%s\n' ${lib.escapeShellArg kernel.version} > "$out/kernel-version"
        '';
    };
in lib.foldl' (result: version: result // checksFor version) { } series
