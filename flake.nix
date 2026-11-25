{
  description = "Music production on NixOS: realtime audio through musnix and PipeWire, and Windows plugins through yabridge.";

  # Realtime basics (threadirqs, audio-group limits, ALSA sequencer, plugin
  # search paths, rtcqs). Consumers should make its nixpkgs follow theirs:
  #   nixos-audio.inputs.musnix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.musnix.url = "github:musnix/musnix";

  outputs =
    { self, musnix }:
    {
      nixosModules = {
        audio = {
          key = "nixos-audio";
          imports = [
            musnix.nixosModules.musnix
            ./modules/audio.nix
          ];
        };
        default = self.nixosModules.audio;
      };
    };
}
