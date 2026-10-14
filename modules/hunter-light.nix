{ source }:
{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.hunter-light;
  light = pkgs.callPackage ../pkgs/hunter-light { src = source; };
  permissions = import ./permissions.nix { inherit pkgs; };
in {
  imports = [ ./hunter-driver.nix ];

  options.hardware.hunter-light.enable = lib.mkEnableOption ''
    Hunter FRD-WX9 lighting CLI and shared Huawei driver. All local users
    may write the three lighting nodes without sudo (permissions 0222).
    Linux 6.18 and BIOS 1.18 are the initial support target
  '';

  config = lib.mkIf cfg.enable {
    hardware.hunter-driver = {
      enable = true;
      source = source.outPath;
    };
    environment.systemPackages = [ light ];
    services.udev.extraRules = ''
      ACTION=="add|bind|change", SUBSYSTEM=="platform", KERNEL=="huawei-wmi", DRIVER=="huawei-wmi", RUN+="${permissions}"
    '';
  };
}
