#!/bin/sh
# Append certificates for selected modules, including in-tree replacements.
set -eu
[ "$#" -eq 1 ] || { echo 'Usage: merge-module-certificates.sh module-directory' >&2; exit 2; }
cd -- "$1"
test -f modules.cer
test -f modules.order
test -f modules.dep

while IFS=: read -r module dependencies; do
    [ -n "$module" ] || continue
    module=${module%.gz}
    module=${module%.xz}
    module=${module%.zst}
    case "$module" in
        *.ko) ;;
        *) echo "Unexpected module path: $module" >&2; exit 1 ;;
    esac
    certificate="$module.cer"
    if [ -f "$certificate" ]; then
        [ -s "$certificate" ] || { echo "Empty module certificate: $certificate" >&2; exit 1; }
        cat -- "$certificate" >> modules.cer
    elif ! grep -Fxq -- "$module" modules.order; then
        echo "Missing external module certificate: $certificate" >&2
        exit 1
    fi
done < modules.dep
