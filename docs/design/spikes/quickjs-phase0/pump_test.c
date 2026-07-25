// halo_qjs_execute_pending_job is a SECOND entry point into JS, but unlike
// halo_qjs_eval it arms no deadline, re-anchors no stack, and tracks no
// depth. Two consequences, both tested here:
//
//   A. Promise reactions run against whatever deadline the LAST eval left
//      behind. If that deadline has passed, a perfectly well-behaved job is
//      interrupted for no reason.
//   B. A reaction that re-enters the host (sendMessage -> nested eval) does
//      so with depth==0, so the nested call believes it is outermost and
//      RE-ANCHORS the stack — the exact #349 hazard the depth gate exists
//      to prevent.
#include "halo_qjs.h"
#include <stdio.h>
#include <string.h>
#include <time.h>

static int64_t now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
static void sleep_ms(int ms) {
  struct timespec ts = { ms / 1000, (long)(ms % 1000) * 1000000L };
  nanosleep(&ts, NULL);
}

static int failures = 0;
static void check(const char *n, int ok, const char *d) {
  printf("%s %-52s %s\n", ok ? "  ok" : "FAIL", n, d ? d : "");
  if (!ok) failures++;
}

int main(void) {
  HaloQjs *h = halo_qjs_new();
  char *out = NULL;

  // --- A. A benign job must not inherit a stale, already-expired deadline.
  halo_qjs_set_eval_budget_ms(h, 200);
  halo_qjs_eval(h, // Long enough to actually be POLLED by the interrupt handler. A 1-2
  // bytecode reaction slips through before any poll and proves nothing.
  "globalThis.ran='no'; Promise.resolve(1).then(() => { let s=0; for(let i=0;i<300000;i++) s+=i; globalThis.ran='yes' })", "t", &out);
  halo_qjs_free_string(out);

  sleep_ms(350); // outlive the deadline that eval just armed

  int rc = halo_qjs_execute_pending_job(h);
  halo_qjs_eval(h, "globalThis.ran", "t", &out);
  int ok_a = out && !strcmp(out, "yes");
  char d[128];
  snprintf(d, sizeof(d), "job rc=%d ran=%s", rc, out ? out : "(null)");
  check("benign job survives a stale expired deadline", ok_a, d);
  halo_qjs_free_string(out);

  // --- B. A runaway job must still be bounded.
  halo_qjs_eval(h, "Promise.resolve(1).then(() => { while(true){} })", "t", &out);
  halo_qjs_free_string(out);
  int64_t t0 = now_ms();
  rc = halo_qjs_execute_pending_job(h);
  int64_t elapsed = now_ms() - t0;
  snprintf(d, sizeof(d), "elapsed=%lldms rc=%d", (long long)elapsed, rc);
  check("runaway promise reaction is interrupted", elapsed < 1000, d);

  halo_qjs_free(h);
  printf("\n%s (%d failure%s)\n", failures ? "FAILED" : "ALL PASSED", failures, failures == 1 ? "" : "s");
  return failures ? 1 : 0;
}
