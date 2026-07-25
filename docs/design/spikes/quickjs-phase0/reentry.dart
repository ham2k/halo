// Phase 0, corrected: the REAL kernel protocol + the re-entrancy the host
// actually performs. extensions/sdk/src/kernel.ts:55 declares
//   sendMessage(channel: string, message: string): void
// and kernel.ts:70 deletes the global afterwards.
//
// halo_extension_host.dart's kvGet/kvSet path reaches _js.hostResponse(...)
// with NO await, so an async Dart function runs straight through and
// re-enters JS_Eval from inside the sendMessage callback. That nested
// entry is what this proves.

import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

typedef _SendNative = Void Function(Pointer<Void>, Pointer<Char>, Pointer<Char>);

int failures = 0;
void check(String name, bool ok, [String? d]) {
  print('${ok ? "  ok" : "FAIL"} ${name.padRight(48)} ${d ?? ""}');
  if (!ok) failures++;
}

final _proc = DynamicLibrary.process();
final _malloc = _proc.lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>('malloc');
final _free = _proc.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free');

Pointer<Char> toC(String s) {
  final b = utf8.encode(s);
  final p = _malloc(b.length + 1).cast<Uint8>();
  p.asTypedList(b.length + 1)
    ..setAll(0, b)
    ..[b.length] = 0;
  return p.cast();
}

String fromC(Pointer<Char> p) {
  if (p == nullptr) return '';
  final b = p.cast<Uint8>();
  var n = 0;
  while (b[n] != 0) n++;
  return utf8.decode(Uint8List.view(b.asTypedList(n).buffer, 0, n));
}

class Qjs {
  final DynamicLibrary lib;
  late final Pointer<Void> h;
  final _cbs = <NativeCallable>[]; // EVERY callable must be closed or the isolate never exits

  late final _new = lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>('halo_qjs_new');
  late final _ev = lib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<Char>, Pointer<Char>, Pointer<Pointer<Char>>),
      int Function(Pointer<Void>, Pointer<Char>, Pointer<Char>, Pointer<Pointer<Char>>)>('halo_qjs_eval');
  late final _setFn = lib.lookupFunction<
      Void Function(Pointer<Void>, Pointer<Char>, Pointer<NativeFunction<_SendNative>>, Pointer<Void>),
      void Function(Pointer<Void>, Pointer<Char>, Pointer<NativeFunction<_SendNative>>, Pointer<Void>)>('halo_qjs_set_host_fn');
  late final _freeStr = lib.lookupFunction<Void Function(Pointer<Char>), void Function(Pointer<Char>)>('halo_qjs_free_string');
  late final _dispose = lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('halo_qjs_free');

  Qjs(this.lib) { h = _new(); }

  void onSend(void Function(String channel, String message) fn) {
    final cb = NativeCallable<_SendNative>.isolateLocal(
        (Pointer<Void> _, Pointer<Char> ch, Pointer<Char> msg) => fn(fromC(ch), fromC(msg)));
    _cbs.add(cb);
    final name = toC('sendMessage');
    _setFn(h, name, cb.nativeFunction, nullptr);
    _free(name.cast());
  }

  (bool, String) eval(String code) {
    final c = toC(code), f = toC('<t>');
    final o = _malloc(sizeOf<Pointer<Char>>()).cast<Pointer<Char>>();
    o.value = nullptr;
    final rc = _ev(h, c, f, o);
    final s = fromC(o.value);
    if (o.value != nullptr) _freeStr(o.value);
    _free(c.cast()); _free(f.cast()); _free(o.cast());
    return (rc == 0, s);
  }

  void dispose() {
    _dispose(h);
    for (final c in _cbs) c.close(); // else the isolate stays alive forever
    _cbs.clear();
  }
}

void main() async {
  final q = Qjs(DynamicLibrary.open('/tmp/qjs-spike/libhaloqjs.dylib'));

  // 1. Real protocol: two args, void return.
  String? gotCh, gotMsg;
  q.onSend((ch, msg) { gotCh = ch; gotMsg = msg; });
  var (ok, out) = q.eval("sendMessage('polo', JSON.stringify({type:'log'})); 'sent'");
  check('sendMessage(channel, message) reaches Dart', ok && gotCh == 'polo' && gotMsg == '{"type":"log"}', '$gotCh / $gotMsg');

  // 2. The kernel DELETES the global as its containment boundary.
  (ok, out) = q.eval("delete globalThis.sendMessage; typeof globalThis.sendMessage");
  check('global is configurable (kernel can delete it)', ok && out == 'undefined', out);

  // 3. THE ONE THAT MATTERS: re-enter eval from inside the callback, exactly
  //    as the kvGet/kvSet host path does via hostResponse.
  final q2 = Qjs(DynamicLibrary.open('/tmp/qjs-spike/libhaloqjs.dylib'));
  var nested = 0;
  q2.onSend((ch, msg) {
    nested++;
    q2.eval("globalThis.fromNested = 'set-by-reentrant-eval'"); // JS_Eval inside JS_Eval
  });
  (ok, out) = q2.eval("sendMessage('polo','x'); globalThis.fromNested");
  check('re-entrant JS_Eval from inside callback', ok && out == 'set-by-reentrant-eval', out);
  check('callback ran exactly once', nested == 1, 'n=$nested');

  // 4. Deeper: two levels of nesting.
  var depth = 0;
  final q3 = Qjs(DynamicLibrary.open('/tmp/qjs-spike/libhaloqjs.dylib'));
  q3.onSend((ch, msg) {
    depth++;
    if (depth < 3) q3.eval("sendMessage('polo','deeper')");
  });
  (ok, out) = q3.eval("sendMessage('polo','start'); 'survived'");
  check('3-level nested re-entrancy survives', ok && out == 'survived' && depth == 3, 'depth=$depth $out');

  // 5. Engine still healthy after all that nesting.
  (ok, out) = q3.eval("(() => { let s=0; for(let i=0;i<1000;i++) s+=i; return s })()");
  check('engine healthy after nesting', ok && out == '499500', out);

  q.dispose(); q2.dispose(); q3.dispose();

  // 6. Same, on a background isolate (the real deployment shape).
  final iso = await Isolate.run(() {
    final z = Qjs(DynamicLibrary.open('/tmp/qjs-spike/libhaloqjs.dylib'));
    var hit = false;
    z.onSend((c, m) { hit = true; z.eval("globalThis.n='ok'"); });
    final (o2, r) = z.eval("sendMessage('polo','y'); globalThis.n");
    z.dispose();
    return o2 && hit ? r : 'FAILED';
  });
  check('re-entrancy works on background isolate', iso == 'ok', iso);

  print('\n${failures == 0 ? "ALL PASSED" : "FAILED"} ($failures failure${failures == 1 ? "" : "s"})');
}
