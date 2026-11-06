{ src }:
{ config, lib, pkgs, ... }:

let
  hunter = pkgs.callPackage ../pkgs/hunter.nix { inherit src; };
in {
  options.hardware.hunter = {
    enable = lib.mkEnableOption "HONOR Hunter driver and the hunter command";

    waybar = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run `hunter watch` as a user service feeding
        $XDG_RUNTIME_DIR/hunter/status.json for Waybar.
      '';
    };
  };

  config = lib.mkIf config.hardware.hunter.enable {
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../pkgs/hunter-driver.nix { inherit src; })
    ];
    boot.kernelModules = [ "huawei_wmi" ];
    environment.systemPackages = [ hunter ];

    # The kernel refuses world-writable sysfs files; let every user switch the lights.
    services.udev.extraRules = ''
      ACTION=="add|bind", SUBSYSTEM=="platform", KERNEL=="huawei-wmi", DRIVER=="huawei-wmi", RUN+="${pkgs.coreutils}/bin/chmod 0222 /sys%p/hunter_light/logo /sys%p/hunter_light/keyboard /sys%p/hunter_light/wind"
    '';

    systemd.user.services.hunter = lib.mkIf config.hardware.hunter.waybar {
      description = "Hunter status file for Waybar";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${hunter}/bin/hunter watch -o %t/hunter/status.json -s waybar -S 8";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %t/hunter";
        Restart = "always";
        # The driver starts with the system; retry instead of failing on boot.
        RestartSec = 5;
      };
    };

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
