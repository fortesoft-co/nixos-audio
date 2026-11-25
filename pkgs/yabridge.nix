# yabridge and yabridgectl from the main branch, built against the given Wine.
#
# nixpkgs ships yabridge 5.1.1 pinned to Wine 9.21. The main branch has the
# Wine 9.22+ GUI fixes (merged April 2026) and the Bitwig VST3 freeze fix
# (#505), but no tagged release yet. Once nixpkgs ships one (5.2+), consumers
# can set cfg.audio.yabridge.package = pkgs.yabridge and this file can go.
#
# Reuses nixpkgs' own yabridge recipe and patches (from pkgs.path), so it
# needs a nixpkgs that still carries pkgs/by-name/ya/yabridge{,ctl}.
{ pkgs, wine }:
let
  inherit (pkgs) lib fetchFromGitHub;

  version = "5.1.1-unstable-2026-11-08";
  src = fetchFromGitHub {
    owner = "robbert-vdh";
    repo = "yabridge";
    rev = "7529c2d67330f7507649e903ce90782b58153a95";
    hash = "sha256-uJ3fLmmp1X4jUmNkYUWpS5jhNxJZLJsFMWXd918XHTY=";
  };

  # main moved subprojects/asio.wrap to 1.34.2; the other wraps match 5.1.1
  asio = fetchFromGitHub {
    owner = "chriskohlhoff";
    repo = "asio";
    tag = "asio-1-34-2";
    hash = "sha256-B9tFXcmBn7n4wEdnfjw5o90fC/cG5+WMdu/K4T6Y+jI=";
  };

  yabridgectlPatches = "${pkgs.path}/pkgs/by-name/ya/yabridgectl";

  yabridge =
    (pkgs.yabridge.override {
      # the package reads wineWow64Packages.yabridge for its build and runtime Wine
      wineWow64Packages = pkgs.wineWow64Packages // {
        yabridge = wine;
      };
    }).overrideAttrs
      (old: {
        inherit version src;

        postUnpack = old.postUnpack + ''
          rm -rf "$sourceRoot/subprojects/asio"
          cp -R --no-preserve=mode,ownership ${asio} "$sourceRoot/subprojects/asio"
        '';

        # upstream dropped 32-bit libyabridge itself, so that patch no longer applies
        patches = builtins.filter (
          p: !(lib.hasSuffix "libyabridge-drop-32-bit-support.patch" (toString p))
        ) old.patches;
      });

  yabridgectl = pkgs.rustPlatform.buildRustPackage {
    pname = "yabridgectl";
    inherit version src;

    # main moved the Cargo workspace (and Cargo.lock) to the repo root
    buildAndTestSubdir = "tools/yabridgectl";
    cargoHash = "sha256-WQ90IAyoUEDRf/N3XQPSSwZ/Lrtne1Tk6otFPKpA7Ik=";

    patches = [
      # find the chainloader through NIX_PROFILES
      "${yabridgectlPatches}/chainloader-from-nix-profiles.patch"
      # dependencies are hard coded in yabridge, so this check is wrong on NixOS
      "${yabridgectlPatches}/remove-dependency-verification.patch"
    ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    # yabridgectl now puts bridged VST2 files under the first $LXVST_PATH/$VST_PATH
    # entry (musnix makes that ~/.lxvst). Bitwig and most hosts scan ~/.vst, so
    # ignore both and keep yabridge's documented default, ~/.vst/yabridge.
    postFixup = ''
      wrapProgram "$out/bin/yabridgectl" \
        --prefix PATH : ${lib.makeBinPath [ wine ]} \
        --unset LXVST_PATH \
        --unset VST_PATH
    '';

    meta = pkgs.yabridgectl.meta // {
      mainProgram = "yabridgectl";
    };
  };
in
{
  inherit yabridge yabridgectl;
}
