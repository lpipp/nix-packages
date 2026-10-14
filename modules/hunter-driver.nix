{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.hunter-driver;
  supportedKernels = import ../pkgs/hunter-driver/supported-kernels.nix;
in {
  options.hardware.hunter-driver = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      internal = true;
      description = "Enable the driver shared by the Hunter CLI modules.";
    };
    source = lib.mkOption {
      type = lib.types.pathInStore;
      internal = true;
      description = "Pinned source shared by the Hunter CLI modules.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "Hunter modules support x86_64-linux only";
      }
      {
        assertion = builtins.elem
          (lib.versions.majorMinor config.boot.kernelPackages.kernel.version) supportedKernels;
        message = "Hunter modules support Linux series: ${lib.concatStringsSep ", " supportedKernels}";
      }
    ];
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../pkgs/hunter-driver { src = cfg.source; })
    ];
    boot.kernelModules = [ "huawei_wmi" ];
  };
}
