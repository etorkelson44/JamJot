import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/services/practice_sessions.dart';

void main() {
  final now = DateTime(2026, 11, 4, 12);
  late SupabaseClient client;
  late List<Uri> requests;
  late List<Map<String, dynamic>> rows;
  var status = 200;
  setUp(() {
    requests = [];
    rows = [];
    status = 200;
    client = SupabaseClient('https://practice-test.invalid', 'test-key',
        httpClient: MockClient((request) async {
      requests.add(request.url);
      final query = request.url.queryParameters;
      if (query.containsKey('manual_override_seconds')) {
        return http.Response(
            jsonEncode({
              'code': '42703',
              'message':
                  'column sessions.manual_override_seconds does not exist'
            }),
            400,
            request: request,
            headers: {'content-type': 'application/json'});
      }
      final offset = int.parse(query['offset'] ?? '0');
      final limit = int.parse(query['limit'] ?? '50');
      return http.Response(
          status == 200
              ? jsonEncode(rows.skip(offset).take(limit).toList())
              : '{"code":"offline","message":"Connection unavailable"}',
          status,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
  });
  tearDown(() => client.dispose());
  test('reproduces the old query failure against the published schema',
      () async {
    await expectLater(
        client
            .from('sessions')
            .select()
            .isFilter('manual_override_seconds', null),
        throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42703')));
  });
  test('opens an older-schema session without the correction column', () async {
    rows = [
      {'id': 'saved', 'total_seconds': 125, 'session_segments': []}
    ];
    final result = await latestResumablePracticeSession(client, 'child', now);
    expect(result?['id'], 'saved');
    expect(result?['total_seconds'], 125);
    final query = requests.single.queryParametersAll;
    expect(query['student_id'], ['eq.child']);
    expect(query['source'], ['eq.app']);
    expect(query['manual_override_seconds'], isNull);
    expect(
        query['started_at'],
        containsAll([
          'gte.${DateTime(2026, 11, 4).toUtc().toIso8601String()}',
          'lt.${DateTime(2026, 11, 5).toUtc().toIso8601String()}'
        ]));
  });
  test('skips corrected sessions including zero and searches the next page',
      () async {
    rows = [
      for (var i = 0; i < 50; i++) {'id': '$i', 'manual_override_seconds': i},
      {'id': 'resumable', 'manual_override_seconds': null}
    ];
    final result = await latestResumablePracticeSession(client, 'child', now);
    expect(result?['id'], 'resumable');
    expect(requests.length, 2);
    expect(requests.last.queryParameters['offset'], '50');
  });
  test('empty or entirely corrected days have no resumable session', () async {
    expect(await latestResumablePracticeSession(client, 'child', now), isNull);
    rows = [
      {'id': 'corrected', 'manual_override_seconds': 120}
    ];
    expect(await latestResumablePracticeSession(client, 'child', now), isNull);
  });
  test(
      'connection failures stay errors rather than looking like empty practice',
      () async {
    status = 503;
    await expectLater(latestResumablePracticeSession(client, 'child', now),
        throwsA(isA<PostgrestException>()));
  });
}
