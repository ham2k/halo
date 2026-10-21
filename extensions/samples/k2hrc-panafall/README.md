# Panadapter & Waterfall

The radio's panadapter and waterfall in a scene panel, with its span, reference
level and sweep speed, a local contrast control, and click-to-tune. The host
draws the sweeps in the `spectrum` control; they never reach the extension.

Needs a radio whose CAT protocol carries its scope: an Icom IC-705/7300/7610 (at
115200 bps on a serial line), or a FlexRadio, which is mirrored through a DAX IQ
channel.

In this repository:

```sh
node build.mjs
node ../../tools/h2kext-pack.mjs build -o /tmp/k2hrc-panafall.h2kext
```
