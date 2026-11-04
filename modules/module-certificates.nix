{ lib }:
final: prev: {
  aggregateModules = modules:
    (prev.aggregateModules modules).overrideAttrs (old: {
      # Counting modules.order entries loses certificates when depmod replaces
      # an in-tree module with an external module of the same name.
      postBuild = lib.replaceStrings [ ''
        sed "1,$(wc -l < modules.order)d; s/\.ko.*/.ko.cer/" modules.dep \
                | xargs -d'\n' cat >> modules.cer
      '' ] [ ''
        sh ${../pkgs/hunter-driver/merge-module-certificates.sh} .
      '' ] (old.postBuild or "");
    });
}
