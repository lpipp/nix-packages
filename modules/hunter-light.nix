{ source }:
{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.hunter-light;
  light = pkgs.callPackage ../pkgs/hunter-light { src = source; };
  driver = config.boot.kernelPackages.callPackage ../pkgs/hunter-driver { src = source; };
  permissions = import ./permissions.nix { inherit pkgs; };
in {
  options.hardware.hunter-light.enable = lib.mkEnableOption ''
    Hunter FRD-WX9 lighting CLI and shared Huawei driver. All local users
    may write the three lighting nodes without sudo (permissions 0222).
    Linux 6.18 and BIOS 1.18 are the initial support target
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "hardware.hunter-light supports x86_64-linux only";
      }
      {
        assertion = lib.versions.majorMinor config.boot.kernelPackages.kernel.version == "6.18";
        message = "hardware.hunter-light currently requires a Linux 6.18 kernel";
      }
    ];
    environment.systemPackages = [ light ];
    boot.extraModulePackages = [ driver ];
    boot.kernelModules = [ "huawei_wmi" ];
    services.udev.extraRules = ''
      ACTION=="add|bind|change", SUBSYSTEM=="platform", KERNEL=="huawei-wmi", DRIVER=="huawei-wmi", RUN+="${permissions}"
    '';
  };
}
