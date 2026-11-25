# The whole option surface: cfg.audio.*
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.cfg.audio;
  built = import ../pkgs/yabridge.nix {
    inherit pkgs;
    inherit (cfg.yabridge) wine;
  };
in
{
  options.cfg.audio = {
    enable = mkEnableOption "realtime audio (musnix + PipeWire with JACK)";

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users added to the `audio` group, which gets musnix's realtime
        priority and memlock limits.
      '';
    };

    pipewire = {
      rate = mkOption {
        type = types.ints.positive;
        default = 48000;
        description = "Default sample rate of the PipeWire graph.";
      };
      quantum = mkOption {
        type = types.ints.positive;
        default = 256;
        description = ''
          Default buffer size in frames (256 at 48 kHz is about 5.3 ms).
          Clients may ask for anything between minQuantum and maxQuantum.
        '';
      };
      minQuantum = mkOption {
        type = types.ints.positive;
        default = 32;
        description = "Smallest buffer a client may request.";
      };
      maxQuantum = mkOption {
        type = types.ints.positive;
        default = 2048;
        description = "Largest buffer a client may request.";
      };
    };

    preemptFull = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Boot with `preempt=full`: full preemption on a stock kernel built with
        PREEMPT_DYNAMIC (nixpkgs kernels are), without a realtime kernel.
      '';
    };

    yabridge = {
      enable = mkEnableOption "Windows VST2/VST3/CLAP plugins through yabridge";

      wine = mkOption {
        type = types.package;
        default = pkgs.wineWow64Packages.stable;
        defaultText = lib.literalExpression "pkgs.wineWow64Packages.stable";
        description = ''
          The Wine plugins run under. yabridge is built against it, and the
          audio-wine/audio-winetricks helpers use it, so installers and the
          plugin host always agree on the prefix.
        '';
      };

      package = mkOption {
        type = types.package;
        default = built.yabridge;
        defaultText = lib.literalMD "yabridge main branch, built against `cfg.audio.yabridge.wine`";
        description = "yabridge. Set to `pkgs.yabridge` once nixpkgs ships a release with Wine 10+ support.";
      };

      yabridgectl = mkOption {
        type = types.package;
        default = built.yabridgectl;
        defaultText = lib.literalMD "yabridgectl from the same source as `package`";
        description = "yabridgectl, wrapped to keep bridged VST2 files in ~/.vst/yabridge.";
      };

      prefixDir = mkOption {
        type = types.str;
        default = ".local/share/wineprefixes";
        description = ''
          Directory, relative to $HOME, holding one Wine prefix per vendor
          (`audio-<vendor>`). yabridge finds a plugin's prefix from its path,
          so each vendor's installer and copy protection stay separate.
        '';
      };
    };
  };
}
