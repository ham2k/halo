// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Flat C API over QuickJS-NG for the Dart FFI binding.
//
// JSValue DELIBERATELY never crosses this boundary. Its representation is
// architecture-dependent — quickjs.h auto-enables JS_NAN_BOXING when
// INTPTR_MAX < INT64_MAX, so it is a uint64_t on 32-bit targets (Android
// armv7) and a 16-byte {JSValueUnion u; int64_t tag;} struct everywhere
// else. Dart FFI bindings are compile-time, so a by-value JSValue would
// need two incompatible Dart definitions for one binary. Everything here
// is therefore opaque pointers, ints, and UTF-8 char*.
//
// Several QuickJS helpers we need (JS_NewCFunction, JS_ToCStringLen) are
// `static inline` in quickjs.h and are not exported symbols at all — the
// shim calls them from C, which is the only way to reach them.

#ifndef HALO_QJS_H
#define HALO_QJS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define HALO_QJS_API __declspec(dllexport)
#else
#define HALO_QJS_API __attribute__((visibility("default")))
#endif

typedef struct HaloQjs HaloQjs;

/// JS -> host. `arg` is a NUL-terminated UTF-8 string owned by the shim and
/// valid only for the duration of the call. The return value is a
/// NUL-terminated UTF-8 string owned by the CALLEE (Dart): the shim copies
/// it into a JS string before returning and never frees it. Return NULL for
/// "no result" (JS sees undefined).
/// Matches the kernel's real contract: extensions/sdk/src/kernel.ts:55
/// declares `sendMessage(channel: string, message: string): void` — two
/// args, no return value. The kernel then `delete`s the global (kernel.ts:70)
/// as its containment boundary, so the property MUST be configurable.
typedef void (*HaloQjsHostFn)(void *user, const char *channel, const char *message);

HALO_QJS_API HaloQjs *halo_qjs_new(void);
HALO_QJS_API void halo_qjs_free(HaloQjs *h);

/// Evaluates `code`. Returns 0 on success, 1 on JS error.
/// `*out` receives a malloc'd NUL-terminated UTF-8 string — the result
/// coerced to string on success, or "message\nstack" on error. Caller must
/// release it with halo_qjs_free_string. `*out` may be set to NULL if the
/// value could not be stringified.
HALO_QJS_API int halo_qjs_eval(HaloQjs *h, const char *code, const char *filename, char **out);

/// Installs `fn` as a global JS function named `global_name`, callable as
/// `global_name(str)`. Only one is supported (all we need).
HALO_QJS_API void halo_qjs_set_host_fn(HaloQjs *h, const char *global_name, HaloQjsHostFn fn, void *user);

/// Runs one pending job (promise reaction). >0 a job ran, 0 none pending,
/// <0 the job threw.
HALO_QJS_API int halo_qjs_execute_pending_job(HaloQjs *h);

HALO_QJS_API void halo_qjs_set_memory_limit(HaloQjs *h, size_t bytes);
HALO_QJS_API void halo_qjs_set_max_stack_size(HaloQjs *h, size_t bytes);

/// Arms the interrupt handler: any single eval running longer than
/// `budget_ms` is aborted with a catchable JS exception. 0 disables.
/// The budget restarts on each halo_qjs_eval call.
HALO_QJS_API void halo_qjs_set_eval_budget_ms(HaloQjs *h, int64_t budget_ms);

HALO_QJS_API void halo_qjs_free_string(char *s);

/// Diagnostic, for engineDescription.
HALO_QJS_API const char *halo_qjs_version(void);

#ifdef __cplusplus
}
#endif
#endif
