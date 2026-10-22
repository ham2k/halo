# Panadapter & Waterfall

The radio's panadapter and waterfall in a scene panel, with its span, reference
level and sweep speed, a local contrast control, and click-to-tune. The host
draws the sweeps in the `spectrum` control; they never reach the extension.

Needs a supported radio:

- Icom IC-705/7300/7610, at 115200 bps when using a serial line.
- FlexRadio, mirrored through a DAX IQ channel.
- Elecraft K4 over Ethernet, with a separate local TCP spectrum connection on
  port 9201 alongside CAT. It displays the main panadapter with local zoom,
  reference and speed controls. Levels are displayed as received, without an
  RF calibration claim.

The panel shows only the controls each radio supports; contrast, averaging,
frame rate and waterfall rows remain local.

In this repository:

```sh
node build.mjs
node ../../tools/h2kext-pack.mjs build -o /tmp/k2hrc-panafall.h2kext
```

Samples are not included in the app's regular extension build. Install the
resulting `.h2kext` through **Settings → Extensions & Features → Install from
file…**, then add its **Panadapter** panel to an operation. The host must have
the matching radio support.
