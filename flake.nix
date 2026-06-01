{
  description = "Nix flake for the Sentry CLI (getsentry/cli)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            # The Sentry CLI is FSL-1.1-Apache-2.0 (unfree in nixpkgs), so the
            # package needs allowUnfree to evaluate. Set it here on the flake's
            # own pkgs; the resulting derivation is blessed, so consumers that
            # pull `packages.<system>.sentry-cli` do not need allowUnfree set
            # in their own config.
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            inherit system;
          }
        );

      mkSentry =
        { pkgs, system }:
        let
          versions = import ./versions.nix;
        in
        pkgs.callPackage ./package.nix {
          inherit system;
          inherit (versions) version;
          hash = versions.hashes.${system};
        };
    in
    {
      packages = forAllSystems (
        { pkgs, system }:
        let
          sentry = mkSentry { inherit pkgs system; };
        in
        {
          sentry-cli = sentry;
          default = sentry;
        }
      );

      apps = forAllSystems (
        { pkgs, system }:
        let
          sentry = mkSentry { inherit pkgs system; };
        in
        {
          sentry-cli = {
            type = "app";
            program = "${sentry}/bin/sentry";
          };
          default = {
            type = "app";
            program = "${sentry}/bin/sentry";
          };
          # `nix run .#update` — bumps versions.nix to the latest upstream
          # Sentry CLI release and refreshes all hashes.
          update = {
            type = "app";
            program = pkgs.lib.getExe (
              pkgs.writeShellApplication {
                name = "sentry-cli-flake-update";
                runtimeInputs = [
                  pkgs.cacert
                  pkgs.curl
                  pkgs.jq
                  pkgs.nix
                ];
                text = builtins.readFile ./update.sh;
              }
            );
          };
        }
      );

      devShells = forAllSystems (
        { pkgs, system }:
        {
          default = pkgs.mkShell {
            packages = [ (mkSentry { inherit pkgs system; }) ];
          };
        }
      );

      checks = forAllSystems (
        { pkgs, ... }:
        import ./tests/default.nix {
          inherit pkgs self;
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt);
    };
}
