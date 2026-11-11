import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/models/caregiver_invite_message.dart';

void main() {
  final now = DateTime.utc(2026, 11, 11, 12);
  test('inviteStatus: accepted, expired, waiting', () {
    expect(inviteStatus({'used_at': '2026-11-11T10:00:00Z'}, now: now),
        InviteStatus.accepted);
    expect(inviteStatus({'used_at': null, 'expires_at': '2026-11-01T00:00:00Z'},
            now: now),
        InviteStatus.expired);
    expect(inviteStatus({'used_at': null, 'expires_at': '2026-12-11T00:00:00Z'},
            now: now),
        InviteStatus.waiting);
  });
  test('shortDate is empty for missing values', () {
    expect(shortDate(null), '');
    expect(shortDate('2026-11-11T18:00:00Z'), 'Nov 11');
  });
  test('message mentions kid, relation, permissions and link', () {
    final m = caregiverInviteMessage(
        name: 'Eric',
        kidName: 'Ben',
        relation: 'Dad',
        grants: {'full_access': false, 'can_pay': true},
        link: 'https://jamjot.app/#/invite?token=abc');
    expect(m, contains("Ben's Dad"));
    expect(m, contains('can pay for lessons'));
    expect(m, contains('token=abc'));
  });
}
