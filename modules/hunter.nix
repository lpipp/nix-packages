{ src }:
{ config, lib, pkgs, ... }:

{
  options.hardware.hunter.enable = lib.mkEnableOption "HONOR Hunter driver and the hunter command";

  config = lib.mkIf config.hardware.hunter.enable {
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../pkgs/hunter-driver.nix { inherit src; })
    ];
    boot.kernelModules = [ "huawei_wmi" ];
    environment.systemPackages = [ (pkgs.callPackage ../pkgs/hunter.nix { inherit src; }) ];

    # aggregateModules skips as many modules.dep lines as modules.order has,
    # which drops the certificate of a module replacing an in-tree one.
    # Collect the certificate of every selected external module instead.
    nixpkgs.overlays = [
      (final: prev: {
        aggregateModules = modules: (prev.aggregateModules modules).overrideAttrs (old: {
          postBuild = lib.replaceStrings
            [ ''sed "1,$(wc -l < modules.order)d; s/\.ko.*/.ko.cer/" modules.dep'' ]
            [ ''cut -d: -f1 modules.dep | sed 's/\.ko.*/.ko.cer/' | while read -r c; do [ ! -e "$c" ] || echo "$c"; done'' ]
            old.postBuild;
        });
      })
    ];
  };
}
