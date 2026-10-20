// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The shared GL map script (map_gl_script.dart), run for real in QuickJS
// against a stand-in for the browser and for MapLibre. Every backend but the
// pure-Flutter one runs this script, so what it does with a payload is only
// provable here.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_quickjs/halo_quickjs.dart';
import 'package:ham2k_logger/views/map/map_gl_script.dart' show mapGlScript;

/// Just enough of a browser and of MapLibre for a framed `create`, a
/// `setMarkers` and a `snapshot`: timers on a clock the test advances, a map
/// whose events the test fires, and a canvas that says what pixel ratio it
/// was read at.
const fakeBrowser = r'''
var window = globalThis;
var calls = [];
var events = [];
var now = 0;
var timers = [];
var nextTimer = 1;
function setTimeout(fn, ms) { var id = nextTimer++; timers.push({ id: id, at: now + (ms || 0), fn: fn }); return id; }
function clearTimeout(id) { timers = timers.filter(function (t) { return t.id !== id; }); }
function requestAnimationFrame(fn) { return setTimeout(fn, 16); }
function cancelAnimationFrame(id) { clearTimeout(id); }
function advance(ms) {
  var until = now + ms;
  for (;;) {
    var due = timers.filter(function (t) { return t.at <= until; }).sort(function (a, b) { return a.at - b.at; })[0];
    if (!due) break;
    clearTimeout(due.id);
    now = due.at;
    due.fn();
  }
  now = until;
}
window.addEventListener = function () {};
window.removeEventListener = function () {};
function ResizeObserver() {}
ResizeObserver.prototype.observe = function () {};
ResizeObserver.prototype.disconnect = function () {};
var document = {
  // No MapLibre control is ever in one: querySelector finds nothing, as a
  // framed map's, which draws no attribution, finds no credits to tend.
  createElement: function (tag) {
    if (tag === 'canvas') return new FakeCanvas();
    return { style: {}, children: [], appendChild: function (c) { this.children.push(c); }, querySelector: function () { return null; } };
  },
  createTextNode: function (text) { return { text: text }; },
};
// A 2D canvas that keeps what was drawn on it as calls rather than pixels:
// each text with the fill it was drawn in, and each shape filled with the
// fill and alpha it was filled in and the outlines it went round, for a test
// to read back. Its data URL is those shapes.
function FakeCanvas() {
  var canvas = this;
  canvas.width = 0;
  canvas.height = 0;
  var ctx = { texts: [], shapes: [], outlines: [] };
  ['setTransform', 'arc', 'closePath', 'stroke'].forEach(function (name) { ctx[name] = function () {}; });
  ctx.beginPath = function () { ctx.outlines = []; };
  ctx.moveTo = function (x, y) { ctx.outlines.push([[x, y]]); };
  ctx.lineTo = function (x, y) { ctx.outlines[ctx.outlines.length - 1].push([x, y]); };
  ctx.fill = function () { ctx.shapes.push({ fillStyle: ctx.fillStyle, globalAlpha: ctx.globalAlpha, outlines: ctx.outlines }); };
  ctx.measureText = function (text) { return { width: text.length * 8, actualBoundingBoxAscent: 9, actualBoundingBoxDescent: 0 }; };
  ctx.fillText = function (text) { ctx.texts.push({ text: text, fillStyle: ctx.fillStyle }); };
  ctx.getImageData = function (x, y, w, h) { return { width: w, height: h, data: [], texts: ctx.texts.splice(0) }; };
  canvas.getContext = function () { return ctx; };
  canvas.toDataURL = function () { return JSON.stringify(ctx.shapes); };
}
function LngLatBounds() { this.n = 0; this.points = []; }
LngLatBounds.prototype.extend = function (p) { this.n++; this.points.push(p); };
LngLatBounds.prototype.isEmpty = function () { return this.n === 0; };
var sourcesLoaded = true;
function FakeMap(options) {
  var listeners = {};
  var sources = {};
  var layers = {};
  var layerOrder = [];
  var images = {};
  var pixelRatio = null;
  this.options = options;
  this.on = function (type, fn) { (listeners[type] = listeners[type] || []).push({ fn: fn }); };
  this.once = function (type, fn) { (listeners[type] = listeners[type] || []).push({ fn: fn, once: true }); };
  this.fire = function (type) {
    var ls = listeners[type] || [];
    listeners[type] = ls.filter(function (l) { return !l.once; });
    ls.forEach(function (l) { l.fn({}); });
  };
  this.getSource = function (id) { return sources[id]; };
  this.addSource = function (id, spec) {
    sources[id] = {
      spec: spec,
      data: null,
      sets: 0,
      setData: function (data) { this.data = data; this.sets++; },
      updateImage: function (image) { this.spec = Object.assign({}, this.spec, image); this.sets++; },
    };
  };
  this.getLayer = function (id) { return layers[id]; };
  this.addLayer = function (layer, before) {
    layers[layer.id] = layer;
    var at = before ? layerOrder.indexOf(before) : -1;
    if (at < 0) layerOrder.push(layer.id); else layerOrder.splice(at, 0, layer.id);
  };
  this.removeLayer = function (id) { delete layers[id]; layerOrder.splice(layerOrder.indexOf(id), 1); };
  this.removeSource = function (id) { delete sources[id]; };
  this.getStyle = function () { return { layers: layerOrder.map(function (id) { return layers[id]; }) }; };
  // A swap's new style holds none of the host's sources and layers.
  this.setStyle = function () {
    Object.keys(sources).forEach(function (id) { delete sources[id]; });
    Object.keys(layers).forEach(function (id) { delete layers[id]; });
    layerOrder.length = 0;
  };
  this.layerOrder = layerOrder;
  this.hasImage = function (id) { return !!images[id]; };
  this.addImage = function (id, image, options) { images[id] = { image: image, options: options }; };
  this.removeImage = function (id) { delete images[id]; };
  this.images = images;
  this.setPaintProperty = function (id, name, value) { layers[id].paint = Object.assign({}, layers[id].paint, { [name]: value }); };
  this.setLayoutProperty = function (id, name, value) { layers[id].layout = Object.assign({}, layers[id].layout, { [name]: value }); };
  this.resetNorthPitch = function () { calls.push('resetNorthPitch'); };
  this.fitBounds = function (bounds, options) { calls.push('fitBounds'); window.lastFitOptions = options; window.lastFitPoints = bounds.points; };
  this.loaded = function () { return sourcesLoaded; };
  this.isStyleLoaded = function () { return true; };
  this.setPixelRatio = function (r) { pixelRatio = r; calls.push('setPixelRatio ' + r); };
  this.triggerRepaint = function () {};
  this.getCanvas = function () { return { style: {}, toDataURL: function (type) { return 'data:' + type + ';ratio=' + pixelRatio + ';base64,AAAA'; } }; };
  this.getCenter = function () { return { lat: options.center[1], lng: options.center[0] }; };
  this.getZoom = function () { return options.zoom; };
  this.getBounds = function () { return { getSouth: function () { return 40; }, getWest: function () { return -75; }, getNorth: function () { return 41; }, getEast: function () { return -74; } }; };
  this.getBearing = function () { return options.bearing || 0; };
  this.getPitch = function () { return options.pitch || 0; };
  this.getContainer = function () { return options.container; };
  this.queryRenderedFeatures = function (point, options) { window.lastQueryLayers = options && options.layers; return window.hits || []; };
  this.remove = function () {};
  window.fakeMap = this;
}
function Popup() { this.open = false; }
Popup.prototype.setLngLat = function () { return this; };
Popup.prototype.setDOMContent = function () { return this; };
Popup.prototype.addTo = function () { this.open = true; return this; };
Popup.prototype.isOpen = function () { return this.open; };
Popup.prototype.remove = function () { this.open = false; return this; };
var maplibregl = { Map: FakeMap, LngLatBounds: LngLatBounds, AJAXError: function () {}, Popup: Popup };
''';

class GlPage {
  final _js = HaloQuickJs();

  GlPage({required bool framed}) {
    run(fakeBrowser);
    run(mapGlScript);
    final frame = framed ? jsonEncode({'latitude': 41.5, 'longitude': -74.4, 'zoom': 9.25, 'bearing': 0, 'pitch': 0, 'width': 540, 'height': 960}) : 'null';
    run("var container = document.createElement('div'); container.clientWidth = 270; container.clientHeight = 480;");
    run(
      "var handle = window.poloMapGl.create(container, 'light-style', 'dark-style', false, function (kind, message) { events.push([kind, message]); }, false, $frame);",
    );
  }

  String run(String code) {
    final result = _js.eval(code);
    if (!result.ok) fail('JS threw: ${result.text}');
    return result.text;
  }

  void pumpPromises() {
    while (_js.pump() > 0) {}
  }

  /// The messages of the events of [kind] the page has reported since the
  /// last take.
  List<String> takeEvents(String kind) => [
    for (final e in jsonDecode(run('var e = JSON.stringify(events); events = []; e')) as List)
      if (e[0] == kind) e[1] as String,
  ];

  List<String> takeCalls() => (jsonDecode(run('var c = JSON.stringify(calls); calls = []; c')) as List).cast<String>();

  void dispose() => _js.dispose();
}
