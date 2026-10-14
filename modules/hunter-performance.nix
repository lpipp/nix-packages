{ source, performanceSource }:
{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.hunter-performance;
  performance = pkgs.callPackage ../pkgs/hunter-performance { src = performanceSource; };
in {
  imports = [ ./hunter-driver.nix ];

  options.hardware.hunter-performance.enable = lib.mkEnableOption ''
    Hunter FRD-WX9 read-only mode and fan queries with the shared Huawei
    driver. The query nodes are readable by all local users (0444).
    Linux 6.18 and BIOS 1.18 are the initial support target
  '';

  config = lib.mkIf cfg.enable {
    hardware.hunter-driver = {
      enable = true;
      source = source.outPath;
    };
    environment.systemPackages = [ performance ];
  };
}
