# nixos-audio

Music production on NixOS:

- **Realtime audio** through [musnix](https://github.com/musnix/musnix):
  `threadirqs`, realtime priority and memlock limits for the `audio`
  group, ALSA sequencer modules, plugin search paths, and the `rtcqs`
  checker. On top of that, `preempt=full` on stock PREEMPT_DYNAMIC
  kernels, no realtime kernel needed.
- **PipeWire as the only audio server**, with its JACK and PulseAudio
  interfaces and a configurable buffer size.
- **Windows plugins** (VST2, VST3, CLAP) through
  [yabridge](https://github.com/robbert-vdh/yabridge), built from its main
  branch against Wine 11 until a release with Wine 10+ support reaches
  nixpkgs.

## Use

```nix
# flake.nix
inputs.nixos-audio.url = "github:fortesoft-co/nixos-audio";
inputs.nixos-audio.inputs.musnix.inputs.nixpkgs.follows = "nixpkgs";

# host config
imports = [ inputs.nixos-audio.nixosModules.default ];

cfg.audio = {
  enable = true;
  users = [ "alice" ];
  pipewire.quantum = 256; # frames; 256 at 48 kHz is about 5.3 ms
  yabridge.enable = true;
};
```

musnix's own options (`musnix.*`, e.g. `musnix.rtirq.enable` or
`musnix.kernel.realtime`) stay available for anything beyond that.

## Options

| option | default | |
| --- | --- | --- |
| `cfg.audio.enable` | `false` | musnix, PipeWire with JACK and PulseAudio, rtkit |
| `cfg.audio.users` | `[ ]` | added to the `audio` group |
| `cfg.audio.pipewire.rate` | `48000` | graph sample rate |
| `cfg.audio.pipewire.quantum` | `256` | default buffer, in frames |
| `cfg.audio.pipewire.minQuantum` / `maxQuantum` | `32` / `2048` | what clients may request |
| `cfg.audio.preemptFull` | `true` | boot with `preempt=full` |
| `cfg.audio.yabridge.enable` | `false` | yabridge, yabridgectl and the Wine helpers |
| `cfg.audio.yabridge.wine` | `pkgs.wineWow64Packages.stable` | Wine for plugins and installers |
| `cfg.audio.yabridge.package` / `yabridgectl` | main-branch build | swap for `pkgs.yabridge` / `pkgs.yabridgectl` later |
| `cfg.audio.yabridge.prefixDir` | `.local/share/wineprefixes` | per-vendor prefixes, relative to `$HOME` |

## Windows plugins

Give each vendor its own Wine prefix, so one vendor's installer or copy
protection can't break another's. yabridge finds a plugin's prefix from
where its file lives.

```sh
audio-wine somevendor ~/Downloads/SomeVendorInstaller.exe   # ~/.local/share/wineprefixes/audio-somevendor
audio-winetricks somevendor corefonts                         # if a plugin needs it
yabridgectl add ~/.local/share/wineprefixes/audio-somevendor/drive_c/Program\ Files/Common\ Files/VST3
yabridgectl sync
```

`audio-wine` and `audio-winetricks` always use the Wine yabridge was built
against, whatever `wine` is on PATH. Bridged plugins land in
`~/.vst/yabridge`, `~/.vst3/yabridge` and `~/.clap/yabridge`; add those to
your DAW's plugin locations if it doesn't scan them already.

Only 64-bit plugins: the WoW64 Wine builds don't run 32-bit ones, and
yabridge's 32-bit bridge is not built.

Your DAW must be a native package, not a Flatpak: yabridge doesn't work
inside the Flatpak sandbox.

## Tests

```sh
tests/eval.sh   # NIXPKGS=<flake ref> to pin nixpkgs
```
