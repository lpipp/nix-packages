#!/bin/sh
# Build-time guard only; never queries or changes the running kernel.
set -eu
[ "$#" -eq 1 ] || { printf '%s\n' 'Usage: check-kernel.sh modules.builtin' >&2; exit 2; }
[ -r "$1" ] || { printf '%s\n' 'hunter-driver: cannot inspect target modules.builtin' >&2; exit 1; }
if grep -Eq '(^|/)huawei[-_]wmi\.ko$' "$1"; then
    printf '%s\n' 'hunter-driver cannot replace CONFIG_HUAWEI_WMI=y; use a modular kernel' >&2
    exit 1
else
    status=$?
    [ "$status" -eq 1 ] || exit 1
fi
