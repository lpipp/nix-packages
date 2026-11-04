{
  description = "lpipp's Nix packages and NixOS modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hunter-src = {
      url = "github:lpipp/hunter-linux";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, hunter-src }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      packages.x86_64-linux = {
        hunter = pkgs.callPackage ./pkgs/hunter.nix { src = hunter-src; };
        hunter-driver = pkgs.linuxPackages.callPackage ./pkgs/hunter-driver.nix { src = hunter-src; };
        default = self.packages.x86_64-linux.hunter;
      };

      nixosModules.hunter = import ./modules/hunter.nix { src = hunter-src; };
    };
}
