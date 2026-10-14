{
  description = "lpipp's Nix packages and NixOS modules";

  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.11527.2efa67fd26b6/nixexprs.tar.xz";
    hunter-light-src = {
      url = "github:lpipp/hunter-light/9711bfe9d1033fb0e1ddb4fe95cd0fa245fcf96c";
      flake = false;
    };
    hunter-performance-src = {
      url = "github:lpipp/hunter-linux/ad1559e89d700aa7c6becc37b79160ac418a1ccc";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, hunter-light-src, hunter-performance-src }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      source = hunter-light-src;
      light = pkgs.callPackage ./pkgs/hunter-light { src = source; };
      performanceSource = hunter-performance-src;
      performance = pkgs.callPackage ./pkgs/hunter-performance { src = performanceSource; };
      driver = pkgs.linuxPackages.callPackage ./pkgs/hunter-driver { src = source; };
      module = import ./modules/hunter-light.nix { inherit source; };
      performanceModule = import ./modules/hunter-performance.nix { inherit source performanceSource; };
      overlay = final: prev: {
        hunter-light = final.callPackage ./pkgs/hunter-light { src = source; };
        hunter-performance = final.callPackage ./pkgs/hunter-performance { src = performanceSource; };
      };
    in {
      packages.${system} = {
        hunter-light = light;
        hunter-driver = driver;
        hunter-performance = performance;
        default = light;
      };

      overlays.default = overlay;

      nixosModules.hunter-light = module;
      nixosModules.hunter-performance = performanceModule;

      checks.${system} = import ./checks {
        inherit pkgs nixpkgs system source light driver module overlay
          performanceSource performance performanceModule;
      };
    };
}
