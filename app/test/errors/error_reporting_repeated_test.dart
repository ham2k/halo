// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `reportIfRepeated` exists to keep a recoverable, operator-triggered call
// from filing a crash report every time somebody's train enters a tunnel,
// while still catching the one that is genuinely broken. Every half of that
// bargain is load-bearing: report too eagerly and the signal drowns; report
// at-or-above the threshold and a permanently broken call floods anyway;
// forget to reset on success and a long enough session reports everything.

import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/peer/peer_link_types.dart' show PeerMediaDialFailure;

import '../support/error_reporting_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeErrorReportingBackend backend;

  setUp(() {
    backend = FakeErrorReportingBackend();
    ErrorReportingService.resetFailureStreaks();
  });

  tearDown(ErrorReportingService.resetFailureStreaks);

  /// One failed attempt of [key], as a call site would record it.
  void failOnce(String key) => ErrorReportingService.reportIfRepeated(key, StateError('boom'), StackTrace.empty, context: key);

  test('a failure that does not repeat is never uploaded', () async {
    await withErrorHooks(() async {
      failOnce('a');
      failOnce('a');
      expect(backend.exceptions, isEmpty);
    }, backend: backend);
  });

  test('the third consecutive failure is reported, and says how stuck it is', () async {
    await withErrorHooks(() async {
      failOnce('a');
      failOnce('a');
      failOnce('a');
      expect(backend.exceptions, hasLength(1));
      expect(backend.exceptions.single.context, contains('failed 3 times in a row'));
    }, backend: backend);
  });

  /// One failed attempt of [key] that the policy keeps to the console — a
  /// screen pane dialling a firewalled peer.
  void failQuietly(String key) =>
      ErrorReportingService.reportIfRepeated(key, const PeerMediaDialFailure('device-b', SocketException('Connection refused')), StackTrace.empty);

  test('a failure the policy keeps quiet does not count, so the defect behind it still reports', () async {
    // The trap: a call whose COMMON failure is quiet fails that way for as
    // long as the world is the problem — a firewall, no internet — and a
    // streak that counted those would spend its one report on the third
    // quiet one and then sit past the threshold, silent, for whatever
    // defect came next.
    await withErrorHooks(() async {
      for (var i = 0; i < 25; i++) {
        failQuietly('a');
      }
      expect(backend.exceptions, isEmpty, reason: 'known noise is never an upload');
      expect(ErrorReportingService.failureStreak('a'), 0, reason: 'and never a count');

      failOnce('a');
      failOnce('a');
      failOnce('a');
      expect(backend.exceptions, hasLength(1));
      expect(backend.exceptions.single.error, isA<StateError>());
    }, backend: backend);
  });

  test('a quiet failure does not reset the streak either', () async {
    // Not a success: the call still failed. Resetting on it would let a
    // defect that alternates with the world's noise never reach three.
    await withErrorHooks(() async {
      failOnce('a');
      failOnce('a');
      failQuietly('a');
      expect(backend.exceptions, isEmpty);
      failOnce('a');
      expect(backend.exceptions, hasLength(1));
      expect(backend.exceptions.single.error, isA<StateError>());
    }, backend: backend);
  });

  test('a permanently broken call reports once, not forever', () async {
    // The whole reason it fires AT the threshold rather than at-or-above:
    // otherwise a call that can never succeed just trades a flood of single
    // failures for a flood of streak reports.
    await withErrorHooks(() async {
      for (var i = 0; i < 25; i++) {
        failOnce('a');
      }
      expect(backend.exceptions, hasLength(1));
    }, backend: backend);
  });

  test('a success resets the streak, so "repeated" means stuck rather than unlucky', () async {
    await withErrorHooks(() async {
      // Five failures across the session, never three in a row. Without the
      // reset this reports, and any long enough session eventually reports
      // every merely-flaky call.
      failOnce('a');
      failOnce('a');
      ErrorReportingService.recordSuccess('a');
      failOnce('a');
      failOnce('a');
      expect(backend.exceptions, isEmpty);

      failOnce('a');
      expect(backend.exceptions, hasLength(1));
    }, backend: backend);
  });

  test('streaks are per key, so a broken call is not masked by a healthy one', () async {
    await withErrorHooks(() async {
      failOnce('syncTransport:approveLinkRequest');
      failOnce('syncTransport:getAccountData');
      failOnce('syncTransport:approveLinkRequest');
      failOnce('syncTransport:getAccountData');
      expect(backend.exceptions, isEmpty);

      failOnce('syncTransport:approveLinkRequest');
      expect(backend.exceptions, hasLength(1));
      expect(backend.exceptions.single.context, contains('approveLinkRequest'));
    }, backend: backend);
  });
}
