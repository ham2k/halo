// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for distribution-specific analytics (e.g. a proprietary
// build wired to a metrics backend). The OSS app ships with a no-op
// implementation; `HaLoServices` accepts an override at construction time.

abstract class MetricsService {
  void logEvent(String name, {Map<String, Object?> properties = const {}});
  void setUserProperty(String name, String? value);
}

class NoopMetricsService implements MetricsService {
  const NoopMetricsService();

  @override
  void logEvent(String name, {Map<String, Object?> properties = const {}}) {}

  @override
  void setUserProperty(String name, String? value) {}
}
