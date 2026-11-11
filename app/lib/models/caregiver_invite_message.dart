// The ready-written invite message for a caregiver, shared by "Create invite"
// and "Resend" so both say the same thing.

const caregiverGrantLabels = {
  'can_message': 'Part of teacher chats',
  'can_view_calendar': 'Sees the calendar',
  'can_stock_rewards': 'Stocks market rewards',
  'can_adjust_practice': 'Adjusts practice records',
  'can_pay': 'Can pay for lessons',
};

String caregiverInviteMessage({
  required String name,
  required String kidName,
  required String relation,
  required Map<String, dynamic> grants,
  required String link,
}) {
  final full = grants['full_access'] == true;
  final allowed = [
    for (final key in caregiverGrantLabels.keys)
      if (grants[key] == true) caregiverGrantLabels[key]!.toLowerCase(),
  ];
  final permissionLine = full
      ? 'do everything a parent can — full partner access'
      : (allowed.isEmpty
          ? 'follow along with their practice'
          : 'follow along with their practice, plus: ${allowed.join(', ')}');
  return '''Hi $name!

I set you up as $kidName's $relation on JamJot — the app we use for music practice. You'll be able to $permissionLine.

Tap this link, create your free account, and you're in:
$link

(The link is just for you. It works once and expires in 30 days.)''';
}

/// Where an invite stands, for the "Invites sent" list.
enum InviteStatus { accepted, expired, waiting }

InviteStatus inviteStatus(Map<String, dynamic> inv, {DateTime? now}) {
  if (inv['used_at'] != null) return InviteStatus.accepted;
  final exp = DateTime.tryParse('${inv['expires_at'] ?? ''}');
  if (exp != null && exp.isBefore(now ?? DateTime.now())) {
    return InviteStatus.expired;
  }
  return InviteStatus.waiting;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Nov 11" for the "Invites sent" list; empty if the value is missing.
String shortDate(dynamic value) {
  final d = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (d == null) return '';
  return '${_months[d.month - 1]} ${d.day}';
}
