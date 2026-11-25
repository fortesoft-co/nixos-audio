# AGENTS.md

Rules and instructions for agents and humans contributing to this
repository: a NixOS module for music production — realtime audio through
musnix and PipeWire, and Windows plugins through yabridge.

## Content rules (hard — apply to every commit)

- **Content-free by policy.** No host values, users, plugin vendors or
  licenses, paths of a real machine, or any consumer content lives here.
  Which users make music, which plugins they own and what buffer size
  suits their interface belongs to the consumer's host config. This repo
  ships machinery only. Examples and tests use placeholders.
- The repo's history is part of the repo: every rule above applies to
  commit messages too.

## Scratchpad

`.scratch/` (gitignored) is the local scratchpad: throwaway configs and
working notes. Local-only — never commit it, never reference it from
tracked files.

## Module map

```
flake.nix            nixosModules.audio (keyed: imported once), musnix input
modules/options.nix  cfg.audio.* — the whole option surface
modules/audio.nix    musnix + PipeWire/JACK + kernel params; yabridge
                     packages and the audio-wine/audio-winetricks helpers
pkgs/yabridge.nix    yabridge + yabridgectl from the main branch, built
                     against cfg.audio.yabridge.wine
tests/eval.sh        option surface via nixosSystem
```

## Golden rules

1. **Lean on musnix, don't duplicate it.** Realtime limits, threadirqs,
   ALSA sequencer modules and plugin search paths come from musnix.
   Add something here only when musnix lacks it, and prefer setting a
   musnix option over re-implementing its effect.
2. **PipeWire is the only audio server.** No standalone JACK or
   PulseAudio daemons; their clients go through PipeWire's interfaces.
3. **One Wine for plugins and installers.** yabridge is built against
   `cfg.audio.yabridge.wine`, and every helper that runs Windows code
   uses that same Wine. Never fall back to a `wine` from PATH.
4. **The main-branch yabridge build is temporary.** When nixpkgs ships a
   yabridge release with Wine 10+ support, switch the default to
   `pkgs.yabridge` and remove `pkgs/yabridge.nix`.
5. **The flake only sees tracked files.** After creating any file the
   eval must see: `git add` it first.

## Testing

```
tests/eval.sh    NIXPKGS=<flake ref> to pin the eval nixpkgs
```

Must pass before any host integration work. When bumping the yabridge
rev, also build both packages (`cfg.audio.yabridge.package` and
`.yabridgectl`) from a consumer eval: the eval test does not build.
