# ACE Transient Master for Ardour

A prototype transient shaper for Ardour, developed against Ardour 9.8.158 at commit `3f761fc2c8`.

The plugin is an Ardour Lua DSP processor. Its sample-rate audio processing is delegated to a small native C++ helper to keep real-time CPU use low. Ardour's standard plugin editor provides the controls; the processor strip shows an inline response curve that follows the controls.

## Controls

- Attack: transient gain, -12 to +12 dB
- Sustain: body gain, -12 to +12 dB
- Sensitivity: transient weighting, 0.1 to 4
- Release: envelope release, 20 to 500 ms
- Mix: wet/dry, 0 to 100 percent
- Output: output trim, -12 to +12 dB

The inline curve is a display, not a draggable envelope. Adjust the controls in Ardour's plugin window.

## Install in an Ardour source build

1. From the root of an Ardour 9.8.158 checkout, apply `patches/ardour-native-transient-shaper.patch`.
2. Copy `ace_transient_master.lua` into `share/scripts/`.
3. Build Ardour with `python3 ./waf build -j4`.
4. Restart Ardour and insert **ACE Transient Master** after the instrument or on an audio route.

The patch adds the native DSP helper, exposes it to Ardour's Lua API, and adds signal-level tests. Existing instances embed their script source; remove and re-add the plugin after updating it.

## Tests

The Ardour test suite includes a signal-level check that verifies unity pass-through at neutral settings and confirms that +6 dB output gain changes the signal as expected.

## Licensing

The Lua script declares MIT licensing. The native patch modifies Ardour source and remains subject to Ardour's GPL-2.0-or-later licensing.

This is a community prototype, not an official Ardour plugin or upstream feature.
