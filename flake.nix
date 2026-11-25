{
  description = "DeepSeek Harness (dsh) Nix flake — CLI, Web UI & Electron Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgsFor = import nixpkgs { inherit system; };

      mkPackage =
        {
          pkgs,
          desktopScaleFactor ? "1",
        }:
        pkgs.callPackage ./package.nix { inherit desktopScaleFactor; };

      dsh = mkPackage { pkgs = pkgsFor; };
    in
    {
      lib.mkPackage = mkPackage;

      overlays.default = final: _prev: {
        deepseek-harness = mkPackage { pkgs = final; };
        dsh = final.deepseek-harness;
      };

      packages.${system} = {
        default = dsh;
        dsh = dsh;
        deepseek-harness = dsh;
      };

      formatter.${system} = pkgsFor.nixfmt-rfc-style;
    };
}
