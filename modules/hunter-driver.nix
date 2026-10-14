{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.hunter-driver;
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
        assertion = lib.versions.majorMinor config.boot.kernelPackages.kernel.version == "6.18";
        message = "Hunter modules currently require a Linux 6.18 kernel";
      }
    ];
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../pkgs/hunter-driver { src = cfg.source; })
    ];
    boot.kernelModules = [ "huawei_wmi" ];
  };
}
