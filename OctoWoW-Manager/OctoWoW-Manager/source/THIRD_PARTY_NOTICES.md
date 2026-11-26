# Third-party notices

## vanilla-tweaks

`src-tauri/src/core/patcher.rs` is a port of [vanilla-tweaks](https://github.com/brndd/vanilla-tweaks) 1.6.0.

```
MIT License

Copyright (c) 2022 brndd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## gitoxide

The built-in git client (`src-tauri/src/core/git.rs`) uses [gitoxide](https://github.com/GitoxideLabs/gitoxide)
(the `gix` crates), licensed under MIT or Apache-2.0.

## GitAddonsManager

Support for GitAddonsManager's addon layout (multi-addon repositories kept as `<Name>.repo`, with
their addon subfolders moved into AddOns) follows the behaviour of
[GitAddonsManager](https://gitlab.com/woblight/GitAddonsManager) (GPL-3.0). No code is copied.

## Modernization feature reference (local build 3.0.4)

The feature list, original download locations and requested hover descriptions were
referenced from Dusk's Modernization Tool (Dusk-92):
https://octowow.st/git/Dusk/Modernization-Tool (revision 3973c5b302).
The Manager implementation is independent Rust/React code. Cross-faction resurrection
and Bluemoon patch bytes are from tubtubs/vanilla-tweaks (MIT), covered by the
vanilla-tweaks notice above: https://github.com/tubtubs/vanilla-tweaks.

Visual/audio packs are fetched on demand from Project Reforged, the RetroCro-linked
mirrors, seacrabsam/patch-herb, Macumbafeh/NoErrorSounds, notsureawake/FishPing and
spzilyk/Warlock-Muted-Demons. Their respective rights and notices remain with their
authors; this custom build does not embed or redistribute the packs.

DucielPerf is downloaded from https://octowow.st/git/Hapto/DucielPerf/releases.
See the upstream license at https://octowow.st/git/Hapto/DucielPerf/src/branch/main/LICENSE.
The recommended nampower DLL is the supplied brues-code build at revision 99d8d36.
Mute Billy uses an original silent WAV in a standalone MPQ. The sound path was
identified from the duck change in Rook’s RaidVisuals-OctoWoW, based on MarcelineVQ’s
raid visuals. No RaidVisuals data tables or audio are bundled.
https://octowow.st/git/Rook/RaidVisuals-OctoWoW
