# Panadapter & Waterfall

The radio's panadapter and waterfall in a scene panel, with its span, reference
level and sweep speed, a local contrast control, and click-to-tune. The host
draws the sweeps in the `spectrum` control; they never reach the extension.

Needs a supported radio:

- Icom IC-705/7300/7610, at 115200 bps when using a serial line.
- FlexRadio, mirrored through a DAX IQ channel.
- Elecraft K4 over Ethernet, with a separate local TCP spectrum connection on
  port 9201 alongside CAT, or the shared secure remote connection. Main and Sub
  are separate logical radios sharing the device's connection. Main, Sub,
  and Both choose which receivers to display. Each has its own local zoom,
  reference, speed, contrast, averaging, frame rate, waterfall rows, and display
  mode. Both shows compact span and reference controls to leave room for both
  waterfalls; select Main or Sub for that receiver's full controls. Hidden
  receivers keep their waterfall history when switching views. Display choices
  are held in memory per panel and logical radio; they are not saved across
  app restarts. Each scope uses its receiver's frequency, filter and tuning
  capabilities. Levels are displayed as received, without an RF calibration claim.

The panel shows only the controls each radio supports; contrast, averaging,
frame rate and waterfall rows remain local.
The panel follows the designated radio and offers Both when the host reports
exactly two logical radios belonging to the same device. Changing the displayed
receiver does not change the logging radio.

In this repository:

```sh
node build.mjs
node ../../tools/h2kext-pack.mjs build -o /tmp/k2hrc-panafall.h2kext
```

Samples are not included in the app's regular extension build. Install the
resulting `.h2kext` through **Settings → Extensions & Features → Install from
file…**, then add its **Panadapter** panel to an operation. The host must have
the matching radio support.
