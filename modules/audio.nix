# Implementation: musnix for the realtime basics, PipeWire as the only audio
# server (with its JACK and PulseAudio interfaces), and yabridge.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cfg.audio;
  yb = cfg.yabridge;

  usage = cmd: ''
    if [ $# -lt 1 ]; then
      echo "usage: ${cmd} <vendor> [args...]   (prefix: \$HOME/${yb.prefixDir}/audio-<vendor>)" >&2
      exit 1
    fi
  '';

  # Installers and license managers run under the same Wine yabridge hosts
  # plugins with; a plain `wine` on PATH may be another version.
  audio-wine = pkgs.writeShellApplication {
    name = "audio-wine";
    text = ''
      ${usage "audio-wine"}
      vendor=$1
      shift
      export WINEPREFIX="$HOME/${yb.prefixDir}/audio-$vendor"
      mkdir -p "$(dirname "$WINEPREFIX")"
      exec ${yb.wine}/bin/wine "$@"
    '';
  };

  audio-winetricks = pkgs.writeShellApplication {
    name = "audio-winetricks";
    text = ''
      ${usage "audio-winetricks"}
      vendor=$1
      shift
      export WINEPREFIX="$HOME/${yb.prefixDir}/audio-$vendor"
      export WINE=${yb.wine}/bin/wine
      export WINESERVER=${yb.wine}/bin/wineserver
      exec ${pkgs.winetricks}/bin/winetricks "$@"
    '';
  };
in
{
  imports = [ ./options.nix ];

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      musnix = {
        enable = true;
        rtcqs.enable = lib.mkDefault true;
      };

      boot.kernelParams = lib.mkIf cfg.preemptFull [ "preempt=full" ];

      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
        extraConfig.pipewire."92-nixos-audio"."context.properties" = {
          "default.clock.rate" = cfg.pipewire.rate;
          "default.clock.quantum" = cfg.pipewire.quantum;
          "default.clock.min-quantum" = cfg.pipewire.minQuantum;
          "default.clock.max-quantum" = cfg.pipewire.maxQuantum;
        };
      };

      users.users = lib.genAttrs cfg.users (_: {
        extraGroups = [ "audio" ];
      });

      assertions = [
        {
          assertion =
            cfg.pipewire.minQuantum <= cfg.pipewire.quantum
            && cfg.pipewire.quantum <= cfg.pipewire.maxQuantum;
          message = "cfg.audio.pipewire: need minQuantum <= quantum <= maxQuantum.";
        }
      ];
    })

    (lib.mkIf yb.enable {
      environment.systemPackages = [
        yb.package
        yb.yabridgectl
        audio-wine
        audio-winetricks
      ];
    })
  ];
}
