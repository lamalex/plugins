{
  description = "moon plugins (launis fork) — builds the ruby_toolchain WASM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ (import rust-overlay) ]; };

        # Pinned by rust-toolchain.toml (1.96.0); plugins compile to wasm32-wasip1.
        rustToolchain = pkgs.rust-bin.stable."1.96.0".default.override {
          targets = [ "wasm32-wasip1" ];
        };
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # cdylib -> wasm32-wasip1: crane's default cargo-install doesn't apply,
        # so build explicitly and copy the artifact out.
        rubyToolchainWasm =
          let
            src = craneLib.cleanCargoSource ./.;
            commonArgs = {
              inherit src;
              pname = "ruby_toolchain";
              version = "0.1.0";
              strictDeps = true;
              doCheck = false;
              CARGO_BUILD_TARGET = "wasm32-wasip1";
              cargoExtraArgs = "-p ruby_toolchain";
            };
            cargoArtifacts = craneLib.buildDepsOnly commonArgs;
          in
          craneLib.mkCargoDerivation (commonArgs // {
            inherit cargoArtifacts;
            buildPhaseCargoCommand = "cargo build --release -p ruby_toolchain --target wasm32-wasip1";
            installPhaseCommand = ''
              mkdir -p $out/lib
              cp target/wasm32-wasip1/release/ruby_toolchain.wasm $out/lib/
            '';
          });
      in
      {
        packages.ruby-toolchain = rubyToolchainWasm;
        packages.default = rubyToolchainWasm;
      });
}
