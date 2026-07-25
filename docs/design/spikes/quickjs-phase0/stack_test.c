// Does anything actually detect a broken stack re-anchor?
//
// halo_qjs_eval re-anchors QuickJS's stack_top ONLY on the outermost entry.
// Re-anchoring a NESTED entry would hand that frame a full fresh budget
// measured from an already-deep sp, so total native stack used approaches
// 2x the configured limit — overflowing the real OS stack. That is #349's
// failure mode, and it is uncatchable.
//
// Run: ./stack_test [js_depth]
//   exit 0 = guard held (RangeError, catchable)
//   exit 139/SIGSEGV or "NO GUARD" = the anchor is broken
#include "halo_qjs.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static HaloQjs *g;
static int nested_ran = 0;
static const char *nested_result = "(never ran)";
static char nested_buf[256];

// Fires at the bottom of the outer recursion — i.e. with most of the stack
// budget already consumed — and re-enters the engine, exactly as the host
// does from the send callback.
static void on_send(void *user, const char *ch, const char *msg) {
  (void)user; (void)ch; (void)msg;
  if (nested_ran) return;
  nested_ran = 1;
  char *o = NULL;
  // Unbounded recursion inside the NESTED eval. With a correct anchor this
  // trips QuickJS's guard almost immediately, because the budget is measured
  // from the OUTER entry and is nearly exhausted. With a broken anchor it
  // gets a whole fresh budget from here and runs off the real stack.
  // Report the depth the NESTED eval reaches before QuickJS refuses it.
  // With a correct (depth-gated) anchor the budget is measured from the OUTER
  // entry and is already partly spent, so this is SHALLOW. With a broken
  // anchor the nested frame gets a whole fresh budget and goes DEEP. That
  // difference is deterministic and needs no segfault to observe.
  halo_qjs_eval(g, "(function(){ let d=0; function r(){ d++; r() } try { r() } catch(e){} return d })()", "nested", &o);
  snprintf(nested_buf, sizeof(nested_buf), "%s", o ? o : "(null)");
  nested_result = nested_buf;
  halo_qjs_free_string(o);
}

int main(int argc, char **argv) {
  const int depth = argc > 1 ? atoi(argv[1]) : 12000;
  g = halo_qjs_new();
  halo_qjs_set_host_fn(g, "sendMessage", on_send, NULL);
  // Well under the ~8MB main-thread stack, so ONE budget fits but TWO do not.
  halo_qjs_set_max_stack_size(g, 4 * 1024 * 1024);

  char script[256];
  snprintf(script, sizeof(script),
           "function d(n){ if(n<=0){ sendMessage('c','m'); return 0 } return 1+d(n-1) }"
           "try { d(%d); 'outer-ok' } catch(e) { 'outer-caught: ' + e.message }",
           depth);

  char *out = NULL;
  int rc = halo_qjs_eval(g, script, "outer", &out);
  printf("js_depth=%d  outer rc=%d  outer=%s\n", depth, rc, out ? out : "(null)");
  printf("nested ran=%d  nested=%s\n", nested_ran, nested_result);
  halo_qjs_free_string(out);
  halo_qjs_free(g);

  if (!nested_ran) {
    printf("\nINCONCLUSIVE: outer never reached sendMessage (lower js_depth).\n");
    return 2;
  }
  // The guard held iff the nested runaway recursion was refused by QuickJS
  // rather than by the operating system.
  long nd = atol(nested_result);
  printf("nested reached depth %ld (outer was at %d)\n", nd, depth);
  // A correctly gated anchor leaves the nested call much less headroom than a
  // fresh budget would. Threshold sits between the two measured regimes.
  // Empirical threshold: measured 2225 (gated) vs 4295 (ungated) on macOS
  // arm64 with a 4MB budget and outer depth 2000 — the ~2x gap is the fresh
  // budget the ungated anchor hands the nested frame. Absolute numbers are
  // frame-size dependent, so re-measure both regimes when porting.
  if (nd > 0 && nd < 3000) {
    printf("\nOK: nested budget inherited from the outer anchor.\n");
    return 0;
  }
  printf("\nNO GUARD: nested got a fresh budget — anchor is not depth-gated.\n");
  return 1;
}
