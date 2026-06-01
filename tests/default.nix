{
  pkgs,
  self,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  packages = self.packages.${system};
in
{
  readme =
    pkgs.runCommand "sentry-cli-readme-test"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        readme = ./../README.md;
        sentry = packages.sentry-cli;
      }
      ''
        set -euo pipefail

        test -f "$readme"

        grep -q "nix run \\." "$readme"
        grep -q "nix build \\.#sentry-cli" "$readme"
        grep -q "sentry-cli\\.url = \"github:kennethhoff/sentry-cli-flake\"" "$readme"
        grep -q "x86_64-linux" "$readme"

        # Ensure the packaged binary exists and is named `sentry`.
        test -x "$sentry/bin/sentry"

        mkdir -p "$out"
      '';

  versionOverride =
    pkgs.runCommand "sentry-cli-version-override-test"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        baseUrl = packages.sentry-cli.src.url;
        overriddenUrl =
          (packages.sentry-cli.override {
            version = "0.0.0-test";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          }).src.url;
      }
      ''
        set -euo pipefail

        echo "$overriddenUrl" | grep -q "0\.0\.0-test"

        mkdir -p "$out"
      '';

  # Run the patched binary offline to prove the interpreter/rpath fixups (and
  # the appended Bun bundle) survived packaging. `--version` is purely local.
  smoke =
    pkgs.runCommand "sentry-cli-smoke-test"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        sentry = packages.sentry-cli;
        version = packages.sentry-cli.version;
      }
      ''
        set -euo pipefail

        export HOME="$PWD/home"
        mkdir -p "$HOME"

        "$sentry/bin/sentry" --version | grep -q "$version"

        mkdir -p "$out"
      '';
}
