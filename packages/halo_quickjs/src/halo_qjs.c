// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

#include "halo_qjs.h"
#include "quickjs/quickjs.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#if defined(_WIN32)
#include <windows.h>
static int64_t halo_now_ms(void) { return (int64_t)GetTickCount64(); }
#else
#include <time.h>
static int64_t halo_now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
#endif

// Bounded on purpose: this is a diagnostic, and a script generating more than
// this many simultaneously-unhandled rejections has a problem the count itself
// communicates better than 10000 log lines would.
#define HALO_MAX_TRACKED_REJECTIONS 32

struct HaloQjs {
  JSRuntime *rt;
  JSContext *ctx;
  HaloQjsHostFn host_fn;
  void *host_user;
  int64_t budget_ms;   // 0 = disabled
  int64_t deadline_ms; // absolute; only meaningful while budget_ms > 0
  int32_t depth;       // nested eval depth; gates stack re-anchoring
  int32_t interrupted; // latched once the deadline fires; cleared at depth 0
  int32_t free_pending; // halo_qjs_free arrived while depth > 0; free on unwind

  // Promise rejections seen but not yet known to be unhandled. See
  // halo_promise_rejection: quickjs reports a rejection the moment it happens,
  // then reports it AGAIN as handled if a catch attaches later, so deciding
  // immediately would log every `Promise.reject(x).catch(...)`.
  JSValue pending_rejections[HALO_MAX_TRACKED_REJECTIONS];
  char *pending_rejection_text[HALO_MAX_TRACKED_REJECTIONS];
  int32_t pending_rejection_count;
  int32_t dropped_rejections; // overflow, reported rather than hidden
  int32_t flushing;           // guards halo_flush_rejections against re-entry
};

static char *halo_strdup(const char *s) {
  if (!s) return NULL;
  size_t n = strlen(s) + 1;
  char *p = (char *)malloc(n);
  if (p) memcpy(p, s, n);
  return p;
}

// Returns non-zero to abort the running script. QuickJS turns that into a
// catchable InternalError, so a runaway hook degrades instead of hanging.
static int halo_interrupt(JSRuntime *rt, void *opaque) {
  (void)rt;
  HaloQjs *h = (HaloQjs *)opaque;
  if (!h) return 0;
  // LATCHED, and that is the whole point. QuickJS raises the interrupt as a
  // JS exception; when it lands inside a NESTED eval (the host re-enters from
  // the send callback), halo_format_exception's JS_GetException CLEARS it.
  // The nested call returns rc=1, the host discards it, and the outer runaway
  // loop resumes — swallowing the interrupt once per iteration, forever.
  // Depth-gating the deadline does NOT help: the deadline had already passed.
  // Staying latched until the outermost call returns makes the outer loop
  // abort on its very next poll.
  if (h->interrupted) return 1;
  if (h->budget_ms <= 0) return 0;
  if (halo_now_ms() > h->deadline_ms) { h->interrupted = 1; return 1; }
  return 0;
}

// Trampoline: JS calls global(str) -> host_fn(user, str) -> JS string.
static JSValue halo_host_trampoline(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
  (void)this_val;
  HaloQjs *h = (HaloQjs *)JS_GetContextOpaque(ctx);
  if (!h || !h->host_fn) return JS_UNDEFINED;

  const char *ch = argc > 0 ? JS_ToCString(ctx, argv[0]) : NULL;
  const char *msg = argc > 1 ? JS_ToCString(ctx, argv[1]) : NULL;

  // JS_ToCString returns NULL when conversion THREW - a Symbol argument, or a
  // toString that throws - leaving a pending exception on the context.
  // Swallowing it and delivering "" would make a broken caller look like a
  // successful send, and would strand the exception to surface inside some
  // later, unrelated call. Propagate it instead.
  if ((argc > 0 && !ch) || (argc > 1 && !msg)) {
    if (ch) JS_FreeCString(ctx, ch);
    if (msg) JS_FreeCString(ctx, msg);
    return JS_EXCEPTION;
  }

  // The host may synchronously re-enter halo_qjs_eval from in here — the
  // kvGet/kvSet path in halo_extension_host.dart reaches hostResponse with
  // no await, so JS_Eval runs nested inside this callback. Nothing per-call
  // is cached across this line for that reason.
  h->host_fn(h->host_user, ch ? ch : "", msg ? msg : "");

  if (ch) JS_FreeCString(ctx, ch);
  if (msg) JS_FreeCString(ctx, msg);

  // If the deadline fired while the host was re-entering us, the nested eval
  // already absorbed the interrupt (its halo_format_exception cleared the
  // pending exception). Returning normally here would let the outer runaway
  // loop resume and swallow the interrupt again on the next iteration — which
  // it does, forever, because nearly every operation the outer loop performs
  // happens inside this callback. Re-raise so the OUTER script unwinds.
  if (h->interrupted) return JS_ThrowInternalError(ctx, "interrupted");

  return JS_UNDEFINED; // kernel.ts discards the return value
}

// Defined below, next to the other conversion helpers; declared here because
// the rejection tracker sits above them.
static char *halo_to_cstring(JSContext *ctx, JSValueConst v);

// An unhandled promise rejection is otherwise completely silent: nothing
// throws, no eval returns non-zero, and the reaction simply never runs.
//
// Reported on the same channel as everything else rather than through a
// separate callback: the host already routes 'polo' messages to its log, and
// a second Dart callback would be another NativeCallable to own and close.
static void halo_promise_rejection(JSContext *ctx, JSValueConst promise,
                                   JSValueConst reason, bool is_handled,
                                   void *opaque) {
  HaloQjs *h = (HaloQjs *)opaque;
  if (!h) return;

  if (is_handled) {
    // A handler attached after the fact — this RETRACTS an earlier report.
    // `Promise.reject(x).catch(f)` produces exactly this pair, so retracting
    // is what keeps ordinary code out of the log.
    for (int32_t i = 0; i < h->pending_rejection_count; i++) {
      if (JS_VALUE_GET_PTR(h->pending_rejections[i]) == JS_VALUE_GET_PTR(promise)) {
        JS_FreeValue(ctx, h->pending_rejections[i]);
        free(h->pending_rejection_text[i]);
        h->pending_rejections[i] = h->pending_rejections[h->pending_rejection_count - 1];
        h->pending_rejection_text[i] = h->pending_rejection_text[h->pending_rejection_count - 1];
        h->pending_rejection_count--;
        return;
      }
    }
    return;
  }

  char *text = halo_to_cstring(ctx, reason);
  // Converting the reason runs JS (toString), which can throw. This is not
  // inside an eval, so a stranded exception would surface in an unrelated
  // later call.
  if (JS_HasException(ctx)) {
    JSValue stranded = JS_GetException(ctx);
    JS_FreeValue(ctx, stranded);
  }

  // Bound-check AFTER the conversion, not before. halo_to_cstring runs
  // arbitrary JS — a `toString` on the rejection reason — and quickjs calls
  // this tracker synchronously at rejection time, so that toString can queue
  // rejections of its own and fill the array while we are inside it. Checking
  // first and appending at the re-read count writes past the end:
  //
  //   Promise.reject({ toString() { for (let i=0;i<32;i++) Promise.reject(i); return 'x' } })
  //
  // put a JSValue at [32], aliasing pending_rejection_text[0..1], and the next
  // flush then passed a JSObject* to strlen and free()d it. Heap corruption
  // from ordinary extension JS, with no host involvement.
  if (h->pending_rejection_count >= HALO_MAX_TRACKED_REJECTIONS) {
    free(text);
    h->dropped_rejections++;
    return;
  }

  int32_t slot = h->pending_rejection_count++;
  h->pending_rejections[slot] = JS_DupValue(ctx, promise);
  h->pending_rejection_text[slot] = text ? text : halo_strdup("(unconvertible rejection value)");
}

// Called once the job queue drains, which is the point at which a rejection
// that still has no handler genuinely is unhandled — the same moment a browser
// fires `unhandledrejection`.
static void halo_flush_rejections(HaloQjs *h) {
  // Re-entrant call: the outer flush already owns this batch. Reporting goes
  // through host_fn, the host is allowed to re-enter the engine synchronously,
  // and engine_runtime_io.dart's _evaluate ends every hostResponse with
  // pump() - which lands straight back here. VERIFIED: without this guard, two
  // rejections plus a re-entering callback abort the process (SIGABRT), and
  // the same rejection is reported once per level on the way down.
  if (h->flushing) return;
  if (!h->pending_rejection_count && !h->dropped_rejections) return;
  h->flushing = 1;

  // Take the whole batch onto the stack and clear the shared state BEFORE
  // reporting any of it, so a re-entrant path sees an empty queue rather than
  // entries this call is partway through freeing.
  JSValue promises[HALO_MAX_TRACKED_REJECTIONS];
  char *texts[HALO_MAX_TRACKED_REJECTIONS];
  int32_t count = h->pending_rejection_count;
  int32_t dropped = h->dropped_rejections;
  for (int32_t i = 0; i < count; i++) {
    promises[i] = h->pending_rejections[i];
    texts[i] = h->pending_rejection_text[i];
  }
  h->pending_rejection_count = 0;
  h->dropped_rejections = 0;

  for (int32_t i = 0; i < count; i++) {
    if (h->host_fn) {
      h->host_fn(h->host_user, "polo:unhandledRejection", texts[i]);
    }
    JS_FreeValue(h->ctx, promises[i]);
    free(texts[i]);
  }

  // Only worth saying alongside a real report. Overflowed rejections are
  // counted but NOT stored, so the retraction scan can never find them when
  // their handlers attach — reporting the bare count made 40 promises that
  // were all subsequently caught indistinguishable from 40 genuinely
  // unhandled ones.
  if (dropped && count && h->host_fn) {
    char note[96];
    snprintf(note, sizeof(note), "(%d further rejections seen but not tracked)",
             (int)dropped);
    h->host_fn(h->host_user, "polo:unhandledRejection", note);
  }
  h->flushing = 0;
}

HaloQjs *halo_qjs_new(void) {
  HaloQjs *h = (HaloQjs *)calloc(1, sizeof(HaloQjs));
  if (!h) return NULL;
  h->rt = JS_NewRuntime();
  if (!h->rt) { free(h); return NULL; }
  h->ctx = JS_NewContext(h->rt);
  if (!h->ctx) { JS_FreeRuntime(h->rt); free(h); return NULL; }
  JS_SetContextOpaque(h->ctx, h);
  JS_SetInterruptHandler(h->rt, halo_interrupt, h);
  JS_SetHostPromiseRejectionTracker(h->rt, halo_promise_rejection, h);
  // Default the stack guard to a value that can actually fire. QuickJS
  // defaults to 1MB, but an extension-host isolate thread gets only about
  // that much on Windows and Android, so QuickJS never trips its own check,
  // the OS stack overflows first, and the process dies with an uncatchable
  // fault - no Dart error, nothing on Sentry. Defaulting here rather than
  // relying on the caller means the safe value is what you get if the caller
  // forgets to set one; Linux threads default to 8MB and can raise it back
  // to 2MB.
  JS_SetMaxStackSize(h->rt, 512 * 1024);
  return h;
}

static void halo_qjs_destroy(HaloQjs *h) {
  for (int32_t i = 0; i < h->pending_rejection_count; i++) {
    JS_FreeValue(h->ctx, h->pending_rejections[i]);
    free(h->pending_rejection_text[i]);
  }
  if (h->ctx) JS_FreeContext(h->ctx);
  if (h->rt) JS_FreeRuntime(h->rt);
  free(h);
}

void halo_qjs_free(HaloQjs *h) {
  if (!h) return;
  // Freeing while a JS frame is still on the stack - i.e. from inside the
  // host callback - pulls the context out from under the code that is about
  // to resume. Verified: segfault, EXC_BAD_ACCESS at 0x0. Defer instead, and
  // destroy on the way out; halo_leave completes it at depth 0. Refusing
  // outright would leak, and crashing is exactly the failure mode this
  // package exists to escape.
  if (h->depth > 0) {
    h->free_pending = 1;
    // Stop calling out immediately. Dart's dispose() does _free(_h) and then
    // closes the NativeCallable behind onSend, so any further sendMessage from
    // the still-unwinding JS frame would invoke a DELETED callback:
    // "Callback invoked after it has been deleted", SIGABRT, no Dart
    // exception. The host is going away; nothing it could say matters now, and
    // the trampoline already treats a NULL host_fn as "no bridge installed".
    h->host_fn = NULL;
    h->host_user = NULL;
    return;
  }
  halo_qjs_destroy(h);
}

void halo_qjs_set_host_fn(HaloQjs *h, const char *global_name, HaloQjsHostFn fn, void *user) {
  if (!h) return;
  h->host_fn = fn;
  h->host_user = user;
  JSValue global = JS_GetGlobalObject(h->ctx);
  // arity 2 (channel, message); JS_SetPropertyStr's default flags are
  // configurable+writable+enumerable, which the kernel's `delete` requires.
  JSValue f = JS_NewCFunction(h->ctx, halo_host_trampoline, global_name, 2);
  JS_SetPropertyStr(h->ctx, global, global_name, f); // takes ownership of f
  JS_FreeValue(h->ctx, global);
}

// Coerces `v` to a malloc'd UTF-8 C string. Never returns quickjs-owned memory.
static char *halo_to_cstring(JSContext *ctx, JSValueConst v) {
  const char *s = JS_ToCString(ctx, v);
  if (!s) return NULL;
  char *copy = halo_strdup(s);
  JS_FreeCString(ctx, s);
  return copy;
}

static char *halo_format_exception(JSContext *ctx) {
  JSValue exc = JS_GetException(ctx);
  char *msg = halo_to_cstring(ctx, exc);

  // Coercing the exception can itself throw — `throw Object.create(null)` has
  // no toString, and a Symbol cannot be converted at all. Returning NULL then
  // produced a hook failure with NO diagnostic text whatsoever
  // ("evaluating invokeHook: "), and left the new exception pending. The eval
  // path guards against the same defect.
  if (!msg) {
    if (JS_HasException(ctx)) {
      JSValue stranded = JS_GetException(ctx);
      JS_FreeValue(ctx, stranded);
    }
    msg = halo_strdup("(exception could not be converted to a string)");
  }

  // Append .stack when present — this is what makes a JS error actionable.
  char *combined = msg;
  if (JS_IsObject(exc)) {
    JSValue stack = JS_GetPropertyStr(ctx, exc, "stack");
    if (!JS_IsUndefined(stack) && !JS_IsException(stack)) {
      char *st = halo_to_cstring(ctx, stack);
      if (st && msg) {
        size_t n = strlen(msg) + strlen(st) + 2;
        combined = (char *)malloc(n);
        if (combined) snprintf(combined, n, "%s\n%s", msg, st);
        else combined = msg;
        if (combined != msg) free(msg);
      }
      free(st);
    }
    JS_FreeValue(ctx, stack);
  }
  JS_FreeValue(ctx, exc);
  return combined;
}

// EVERY entry into JS goes through these — halo_qjs_eval and
// halo_qjs_execute_pending_job both. Keeping the rule in one place is the
// point: the deadline, the stack anchor and the interrupt latch are all
// per-outermost-call state.
static void halo_enter(HaloQjs *h) {
  if (h->depth == 0) {
    // A Dart isolate is not pinned to one OS thread, so QuickJS's recorded
    // stack_top can belong to a thread we are no longer on — re-anchor it.
    // Only at depth 0: re-anchoring a nested entry would hand that frame a
    // full fresh budget measured from an already-deep sp and overflow the
    // real OS stack.
    JS_UpdateStackTop(h->rt);
    if (h->budget_ms > 0) h->deadline_ms = halo_now_ms() + h->budget_ms;
    h->interrupted = 0;
  }
  h->depth++;
}

// NOTE: this can DESTROY h when a deferred free is pending, so every caller
// must treat h as invalid afterwards. Both call sites only touch locals.
static void halo_leave(HaloQjs *h) {
  h->depth--;
  if (h->depth == 0 && h->free_pending) halo_qjs_destroy(h);
}

int halo_qjs_eval(HaloQjs *h, const char *code, const char *filename, char **out) {
  if (out) *out = NULL;
  if (!h || !code) return 1;

  halo_enter(h);

  JSValue v = JS_Eval(h->ctx, code, strlen(code), filename ? filename : "<eval>", JS_EVAL_TYPE_GLOBAL);

  // Stringify INSIDE the depth window. Coercion runs arbitrary JS - a toString
  // that loops forever is exactly as dangerous as the eval itself - and
  // leaving first meant it ran with no deadline armed and no interrupt, so an
  // infinite toString hung here and was then reported as SUCCESS.
  int failed = JS_IsException(v);
  char *s = failed ? halo_format_exception(h->ctx) : halo_to_cstring(h->ctx, v);

  // A value that cannot be stringified is a FAILURE, not success with empty
  // text. JS_ToCString returns NULL only when it threw (a Symbol result, or a
  // throwing toString) and leaves the exception pending - which would later
  // surface inside an unrelated call. Report it and clear it here.
  if (!failed && !s) {
    failed = 1;
    s = JS_HasException(h->ctx) ? halo_format_exception(h->ctx)
                                : halo_strdup("value could not be converted to a string");
  }

  JS_FreeValue(h->ctx, v);
  halo_leave(h); // may destroy h; nothing below touches it

  if (out) *out = s; else free(s);
  return failed ? 1 : 0;
}

int halo_qjs_execute_pending_job(HaloQjs *h) {
  if (!h) return 0;
  // A pending job is a JS entry point in its own right. Without this it arms
  // no deadline (a reaction inherits whatever the LAST eval left behind),
  // re-anchors no stack, and runs at depth 0, so a reaction re-entering the
  // host re-anchors mid-stack and overflows the real OS stack.
  halo_enter(h);
  JSContext *pctx = NULL;
  int r = JS_ExecutePendingJob(h->rt, &pctx);
  // Flush BEFORE halo_leave, not after: halo_leave DESTROYS h when a free was
  // deferred (halo_qjs_free called from inside the callback), so flushing
  // afterwards would touch freed memory. Staying inside the depth window also
  // keeps h alive while host_fn re-enters.
  // Only at the OUTERMOST depth. A nested pump reaching an empty queue does
  // not mean a rejection is unhandled — kernel.ts calls post() inside a
  // `new Promise` executor before the caller's await attaches its handler, and
  // the kvGet/kvSet host path re-enters _evaluate (which pumps) synchronously
  // in between. Flushing there reported a rejection whose handler attached
  // microseconds later: a real, reachable ERROR log for a correctly handled
  // failure (kvSet with a non-String key does it).
  if (r == 0 && h->depth == 1) halo_flush_rejections(h);
  halo_leave(h);
  return r;
}

void halo_qjs_set_memory_limit(HaloQjs *h, size_t bytes) {
  if (h) JS_SetMemoryLimit(h->rt, bytes);
}

void halo_qjs_set_max_stack_size(HaloQjs *h, size_t bytes) {
  if (h) JS_SetMaxStackSize(h->rt, bytes);
}

void halo_qjs_set_eval_budget_ms(HaloQjs *h, int64_t budget_ms) {
  if (h) h->budget_ms = budget_ms;
}

void halo_qjs_free_string(char *s) { free(s); }

const char *halo_qjs_version(void) { static char v[48]; snprintf(v, sizeof(v), "quickjs-ng %d.%d.%d", QJS_VERSION_MAJOR, QJS_VERSION_MINOR, QJS_VERSION_PATCH); return v; }
