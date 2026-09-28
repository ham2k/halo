# Panel Scene Prototypes

Experimental radio front face, weather inspection chart and native controls form, using the public
`scene` / `PanelHook.onEvent` contracts. Requires a host with panel scene support.
All data is simulated; this extension does not fetch weather or control a radio.

The radio keeps requested frequency separate from reported frequency, simulates
2-second CAT acknowledgments, and has buttons for external tuning, disconnection,
and changing acknowledgment delay. Drag the knob horizontally/upward, use the band
slider, or focus either control and use arrows (Shift for larger steps) / the wheel.

The weather chart demonstrates local-only cursor and numeric sample inspection.
Drag, click, or use arrows; no interaction events cross the extension bridge.

In this repository:

```sh
node build.mjs
node ../../tools/h2kext-pack.mjs build -o /tmp/k2hrc-panel-scenes.h2kext
```

For the contract and migration plan, see `docs/design/panel-scenes.md` in the
logger repository. This is an API experiment,
not a replacement for the production weather/solar panels yet.
