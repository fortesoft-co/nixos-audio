#!/usr/bin/env sh
# Eval harness: renders placeholder configs through a real nixosSystem eval
# (this flake's module, musnix included) and checks the option surface.
# Override the nixpkgs with NIXPKGS (a flake ref; must be resolvable locally
# for offline runs). Nothing is built.
set -eu

NIXPKGS="${NIXPKGS:-github:NixOS/nixpkgs/nixpkgs-unstable}"
here=$(cd "$(dirname "$0")/.." && pwd)

nix eval --impure --json --expr "
let
  np = builtins.getFlake \"$NIXPKGS\";
  self = builtins.getFlake \"$here\";
  lib = np.lib;
  mk = extra: lib.nixosSystem {
    system = \"x86_64-linux\";
    modules = [
      self.nixosModules.default
      { users.users.alice.isNormalUser = true; system.stateVersion = \"26.11\"; }
      extra
    ];
  };
  on = mk { cfg.audio = { enable = true; users = [ \"alice\" ]; yabridge.enable = true; }; };
  off = mk { };
  noYb = mk { cfg.audio.enable = true; };
  noPreempt = mk { cfg.audio = { enable = true; preemptFull = false; }; };
  badQuantum = mk { cfg.audio = { enable = true; pipewire.quantum = 4096; }; };
  # only ours: a minimal eval trips base-system assertions (no fileSystems, no boot loader)
  failing = sys: builtins.filter (lib.hasPrefix \"cfg.audio\") (map (a: a.message) (builtins.filter (a: !a.assertion) sys.config.assertions));
  names = sys: map (p: p.name or \"\") sys.config.environment.systemPackages;
  hasPkg = sys: n: builtins.any (lib.hasPrefix n) (names sys);
  props = on.config.services.pipewire.extraConfig.pipewire.\"92-nixos-audio\".\"context.properties\";
  c = on.config;
  ok = cond: msg: if cond then true else throw \"EVAL CHECK FAILED: \${msg}\";
in {
  checks = [
    (ok (c.musnix.enable && c.musnix.rtcqs.enable) \"musnix and rtcqs on\")
    (ok (!off.config.musnix.enable && !off.config.services.pipewire.jack.enable) \"disabled by default\")
    (ok (c.services.pipewire.jack.enable && c.services.pipewire.pulse.enable && c.security.rtkit.enable) \"pipewire with jack + pulse, rtkit\")
    (ok (props.\"default.clock.rate\" == 48000 && props.\"default.clock.quantum\" == 256) \"rate/quantum defaults\")
    (ok (props.\"default.clock.min-quantum\" == 32 && props.\"default.clock.max-quantum\" == 2048) \"quantum bounds\")
    (ok (builtins.elem \"threadirqs\" c.boot.kernelParams) \"threadirqs from musnix\")
    (ok (builtins.elem \"preempt=full\" c.boot.kernelParams) \"preempt=full\")
    (ok (!builtins.elem \"preempt=full\" noPreempt.config.boot.kernelParams) \"preemptFull = false drops it\")
    (ok (builtins.elem \"audio\" c.users.users.alice.extraGroups) \"users join the audio group\")
    (ok (hasPkg on \"audio-wine\" && hasPkg on \"audio-winetricks\" && hasPkg on \"yabridgectl-\" && hasPkg on \"yabridge-\") \"yabridge packages and helpers\")
    (ok (!hasPkg noYb \"audio-wine\" && !hasPkg noYb \"yabridgectl-\") \"yabridge off by default\")
    (ok (lib.hasInfix \"unstable\" c.cfg.audio.yabridge.package.version) \"main-branch yabridge by default\")
    (ok (failing on == [ ]) \"a valid config raises nothing\")
    (ok (lib.any (lib.hasInfix \"minQuantum <= quantum\") (failing badQuantum)) \"quantum above maxQuantum must fail\")
  ];
  pipewire = props;
  kernelParams = c.boot.kernelParams;
}"
echo
echo "EVAL TEST PASSED"
