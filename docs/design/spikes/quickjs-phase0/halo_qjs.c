// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

#include "halo_qjs.h"
#include "quickjs.h"

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

struct HaloQjs {
  JSRuntime *rt;
  JSContext *ctx;
  HaloQjsHostFn host_fn;
  void *host_user;
  int64_t budget_ms;   // 0 = disabled
  int64_t deadline_ms; // absolute; only meaningful while budget_ms > 0
  int32_t depth;       // nested eval depth; gates stack re-anchoring
  int32_t interrupted; // latched once the deadline fires; cleared at depth 0
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

HaloQjs *halo_qjs_new(void) {
  HaloQjs *h = (HaloQjs *)calloc(1, sizeof(HaloQjs));
  if (!h) return NULL;
  h->rt = JS_NewRuntime();
  if (!h->rt) { free(h); return NULL; }
  h->ctx = JS_NewContext(h->rt);
  if (!h->ctx) { JS_FreeRuntime(h->rt); free(h); return NULL; }
  JS_SetContextOpaque(h->ctx, h);
  JS_SetInterruptHandler(h->rt, halo_interrupt, h);
  return h;
}

void halo_qjs_free(HaloQjs *h) {
  if (!h) return;
  if (h->ctx) JS_FreeContext(h->ctx);
  if (h->rt) JS_FreeRuntime(h->rt);
  free(h);
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
// per-outermost-call state, and each was got wrong at least once when this
// logic lived inline at a single call site.
static void halo_enter(HaloQjs *h) {
  if (h->depth == 0) {
    // A Dart isolate is not pinned to one OS thread, so QuickJS's recorded
    // stack_top can belong to a thread we are no longer on — re-anchor it.
    // Only at depth 0: re-anchoring a nested entry would hand that frame a
    // full fresh budget measured from an already-deep sp and overflow the
    // real OS stack, which is #349's failure mode.
    JS_UpdateStackTop(h->rt);
    if (h->budget_ms > 0) h->deadline_ms = halo_now_ms() + h->budget_ms;
    h->interrupted = 0;
  }
  h->depth++;
}

static void halo_leave(HaloQjs *h) { h->depth--; }

int halo_qjs_eval(HaloQjs *h, const char *code, const char *filename, char **out) {
  if (out) *out = NULL;
  if (!h || !code) return 1;

  halo_enter(h);

  JSValue v = JS_Eval(h->ctx, code, strlen(code), filename ? filename : "<eval>", JS_EVAL_TYPE_GLOBAL);
  halo_leave(h);

  int failed = JS_IsException(v);
  char *s = failed ? halo_format_exception(h->ctx) : halo_to_cstring(h->ctx, v);
  JS_FreeValue(h->ctx, v);

  if (out) *out = s; else free(s);
  return failed ? 1 : 0;
}

int halo_qjs_execute_pending_job(HaloQjs *h) {
  if (!h) return 0;
  // A pending job is a JS entry point in its own right. Without this it armed
  // no deadline (a reaction inherited whatever the LAST eval left behind —
  // measured: a benign reaction killed by a deadline that had expired 350ms
  // before it started), re-anchored no stack, and ran at depth 0, so a
  // reaction re-entering the host re-anchored mid-stack: #349 again.
  halo_enter(h);
  JSContext *pctx = NULL;
  int r = JS_ExecutePendingJob(h->rt, &pctx);
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
