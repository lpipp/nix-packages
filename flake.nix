{
  description = "lpipp's Nix packages and NixOS modules";

  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.11527.2efa67fd26b6/nixexprs.tar.xz";
    hunter-light-src = {
      url = "github:lpipp/hunter-light/9711bfe9d1033fb0e1ddb4fe95cd0fa245fcf96c";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, hunter-light-src }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      source = hunter-light-src;
      light = pkgs.callPackage ./pkgs/hunter-light { src = source; };
      driver = pkgs.linuxPackages.callPackage ./pkgs/hunter-driver { src = source; };
      module = import ./modules/hunter-light.nix { inherit source; };
      overlay = final: prev: {
        hunter-light = final.callPackage ./pkgs/hunter-light { src = source; };
      };
    in {
      packages.${system} = {
        hunter-light = light;
        hunter-driver = driver;
        default = light;
      };

      overlays.default = overlay;

      nixosModules.hunter-light = module;

      checks.${system} = import ./checks {
        inherit pkgs nixpkgs system source light driver module overlay;
      };
    };
}
