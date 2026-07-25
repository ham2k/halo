// Does a NESTED eval reset the OUTER eval's interrupt deadline?
// halo_qjs_eval sets deadline_ms on every entry, and the host re-enters
// eval from inside the send callback (kvGet/kvSet). If the deadline is
// shared state, each nested call pushes it out and the outer runaway loop
// never gets interrupted.
#include "halo_qjs.h"
#include <stdio.h>
#include <time.h>

static HaloQjs *g;
static int calls = 0;
static int nesting = 1;
static int64_t t_start = 0;
static int64_t nest_bound_ms = 2000; // harness bound; pass argv[1] to raise it

static int64_t now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void on_send(void *user, const char *ch, const char *msg) {
  (void)user; (void)ch; (void)msg;
  calls++;
  // Bound the experiment so a confirmed bug can't hang forever.
  // TIME-bounded, not count-bounded: a count cap stops nesting so early that
  // a reset deadline would still fire soon after, masking the bug.
  if (now_ms() - t_start > nest_bound_ms) nesting = 0;
  if (nesting) {
    char *o = NULL;
    halo_qjs_eval(g, "1", "nested", &o); // the re-entrant call the host really makes
    halo_qjs_free_string(o);
  }
}

#include <stdlib.h>
int main(int argc, char **argv) {
  if (argc > 1) nest_bound_ms = atoll(argv[1]);
  g = halo_qjs_new();
  halo_qjs_set_host_fn(g, "sendMessage", on_send, NULL);
  halo_qjs_set_eval_budget_ms(g, 200);

  char *out = NULL;
  int64_t t0 = now_ms(); t_start = t0;
  int rc = halo_qjs_eval(g, "while(true){ sendMessage('c','m') }", "outer", &out);
  int64_t elapsed = now_ms() - t0;

  printf("nest_bound=%lldms  budget=200ms  elapsed=%lldms  rc=%d  host_calls=%d\n", (long long)nest_bound_ms, (long long)elapsed, rc, calls);
  printf("result: %s\n", out ? out : "(null)");
  halo_qjs_free_string(out);
  halo_qjs_free(g);

  if (elapsed > 1000) {
    printf("\nBUG CONFIRMED: outer eval ran %lldms against a 200ms budget.\n", (long long)elapsed);
    printf("The nested eval reset the shared deadline, so the interrupt never fired on time.\n");
    return 1;
  }
  printf("\nOK: interrupt fired within budget despite nesting.\n");
  return 0;
}
