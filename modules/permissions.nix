{ pkgs }:

pkgs.writeShellScript "hunter-light-permissions" ''
  set -eu
  [ "$#" -eq 0 ] || { printf '%s\n' 'hunter-light-permissions accepts no arguments' >&2; exit 2; }
  base=/sys/bus/platform/devices/huawei-wmi/hunter_light
  for zone in logo wind keyboard; do
    if [ -e "$base/$zone" ]; then
      ${pkgs.coreutils}/bin/chmod 0222 "$base/$zone"
    fi
  done
''
