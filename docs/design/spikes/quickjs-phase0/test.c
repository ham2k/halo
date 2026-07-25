// Phase 0 spike: C-side assertions for the flat shim.
// Uses the REAL kernel contract: sendMessage(channel, message) -> void
// (extensions/sdk/src/kernel.ts:55).
#include "halo_qjs.h"
#include <stdio.h>
#include <string.h>
#include <time.h>

static int failures = 0;
static void check(const char *name, int ok, const char *detail) {
  printf("%s %-48s %s\n", ok ? "  ok" : "FAIL", name, detail ? detail : "");
  if (!ok) failures++;
}

static int64_t now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

// Stands in for Dart's NativeCallable: two args in, nothing out.
static HaloQjs *g;
static int calls;
static char last_channel[64], last_message[256];
static int nest;          // when set, the callback re-enters eval (as the host does)
static int64_t nest_until; // wall-clock bound on nesting

static void on_send(void *user, const char *ch, const char *msg) {
  (void)user;
  calls++;
  snprintf(last_channel, sizeof(last_channel), "%s", ch ? ch : "");
  snprintf(last_message, sizeof(last_message), "%s", msg ? msg : "");
  if (nest && now_ms() < nest_until) {
    char *o = NULL;
    halo_qjs_eval(g, "1", "nested", &o); // the re-entrant call the real host makes
    halo_qjs_free_string(o);
  }
}

int main(void) {
  printf("== %s ==\n", halo_qjs_version());
  g = halo_qjs_new();
  char *out = NULL;
  int rc;

  rc = halo_qjs_eval(g, "1+1", "t", &out);
  check("eval '1+1' -> 2", rc == 0 && out && !strcmp(out, "2"), out);
  halo_qjs_free_string(out);

  rc = halo_qjs_eval(g, "throw new Error('boom')", "t", &out);
  check("throw -> rc=1, message and stack", rc == 1 && out && strstr(out, "boom") && strstr(out, "at "), out);
  halo_qjs_free_string(out);

  // The real protocol: two args, void return.
  halo_qjs_set_host_fn(g, "sendMessage", on_send, NULL);
  calls = 0;
  rc = halo_qjs_eval(g, "sendMessage('polo', JSON.stringify({type:'log'})); 'sent'", "t", &out);
  check("sendMessage(channel, message) reaches host",
        rc == 0 && calls == 1 && !strcmp(last_channel, "polo") && !strcmp(last_message, "{\"type\":\"log\"}"),
        last_message);
  halo_qjs_free_string(out);

  calls = 0;
  rc = halo_qjs_eval(g, "for(let i=0;i<5;i++) sendMessage('polo','x'); 'done'", "t", &out);
  check("host callable 5x within one eval", rc == 0 && calls == 5, out);
  halo_qjs_free_string(out);

  // The kernel deletes the global as its containment boundary (kernel.ts:70),
  // so the property must be configurable.
  rc = halo_qjs_eval(g, "delete globalThis.sendMessage; typeof globalThis.sendMessage", "t", &out);
  check("global is configurable (kernel can delete it)", rc == 0 && out && !strcmp(out, "undefined"), out);
  halo_qjs_free_string(out);

  // Promises need manual pumping, mirroring the host's 5ms pump loop.
  rc = halo_qjs_eval(g, "globalThis.r='pending'; Promise.resolve(42).then(v=>{globalThis.r=String(v)}); globalThis.r", "t", &out);
  check("promise pending before pump", rc == 0 && out && !strcmp(out, "pending"), out);
  halo_qjs_free_string(out);
  int pumped = halo_qjs_execute_pending_job(g);
  rc = halo_qjs_eval(g, "globalThis.r", "t", &out);
  check("promise settles after one pending job", pumped > 0 && rc == 0 && out && !strcmp(out, "42"), out);
  halo_qjs_free_string(out);

  // Interrupt: impossible with the current engine, which can only be abandoned
  // Dart-side while JS keeps spinning.
  halo_qjs_set_eval_budget_ms(g, 200);
  int64_t t0 = now_ms();
  rc = halo_qjs_eval(g, "while(true){}", "t", &out);
  int64_t plain = now_ms() - t0;
  check("runaway loop interrupted within budget", rc == 1 && plain < 1000, out ? out : "");
  halo_qjs_free_string(out);

  rc = halo_qjs_eval(g, "'alive'", "t", &out);
  check("engine usable after interrupt", rc == 0 && out && !strcmp(out, "alive"), out);
  halo_qjs_free_string(out);

  // REGRESSION: a nested eval must NOT refresh the outer call's deadline.
  // Before the depth gate, each nested eval pushed the deadline out and the
  // outer runaway loop ran 2201ms against a 200ms budget — precisely the case
  // the interrupt exists for, since a runaway hook calls out on every pass.
  {
    HaloQjs *saved = g;
    halo_qjs_set_host_fn(g, "sendMessage", on_send, NULL); // reinstall (deleted above)
    nest = 1;
    nest_until = now_ms() + 2000;
    calls = 0;
    t0 = now_ms();
    rc = halo_qjs_eval(g, "while(true){ sendMessage('c','m') }", "t", &out);
    int64_t elapsed = now_ms() - t0;
    char detail[96];
    snprintf(detail, sizeof(detail), "elapsed=%lldms calls=%d", (long long)elapsed, calls);
    check("nested eval does NOT reset the outer deadline", rc == 1 && elapsed < 1000, detail);
    halo_qjs_free_string(out);
    nest = 0;
    g = saved;
  }
  halo_qjs_set_eval_budget_ms(g, 0);

  // Memory limit — also impossible on Linux/Windows with the current engine,
  // whose stale prebuilts don't export jsSetMemoryLimit.
  HaloQjs *h2 = halo_qjs_new();
  halo_qjs_set_memory_limit(h2, 1024 * 1024);
  rc = halo_qjs_eval(h2, "let a=[]; while(true){ a.push(new Array(10000).fill(1)) } 'done'", "t", &out);
  check("memory limit trips instead of OOMing", rc == 1, out ? out : "");
  halo_qjs_free_string(out);
  halo_qjs_free(h2);

  halo_qjs_free(g);
  printf("\n%s (%d failure%s)\n", failures ? "FAILED" : "ALL PASSED", failures, failures == 1 ? "" : "s");
  return failures ? 1 : 0;
}
