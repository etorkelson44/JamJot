import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import '../services/supabase_service.dart';
import '../theme/jamjot_theme.dart';
import 'send_email.dart';

/// Pulls the secret token out of an invite link.
String inviteTokenFromLink(String link) =>
    Uri.parse(link.replaceFirst('/#/', '/')).queryParameters['token'] ?? '';

/// What happened when JamJot tried to email an invite.
class InviteEmailResult {
  const InviteEmailResult.sent({this.copySent = false})
      : sent = true,
        notConfigured = false,
        error = null;
  const InviteEmailResult.notConfigured()
      : sent = false,
        notConfigured = true,
        copySent = false,
        error = null;
  const InviteEmailResult.failed(this.error)
      : sent = false,
        notConfigured = false,
        copySent = false;
  final bool sent;
  final bool notConfigured;
  final bool copySent;
  final String? error;
}

Future<InviteEmailResult> sendInviteEmail({
  required String token,
  required String toEmail,
  required String subject,
  required String body,
  required bool copyMe,
}) async {
  try {
    final res = await JamJotBackend.client.functions.invoke('send-invite-email',
        body: {
          'token': token,
          'to_email': toEmail,
          'subject': subject,
          'body': body,
          'copy_me': copyMe,
        });
    final data = res.data as Map<String, dynamic>? ?? {};
    if (data['sent'] == true) {
      return InviteEmailResult.sent(copySent: data['copy_sent'] == true);
    }
    if (data['reason'] == 'email_not_configured') {
      return const InviteEmailResult.notConfigured();
    }
    return InviteEmailResult.failed(
        data['error'] as String? ?? 'Could not send the email just now.');
  } on FunctionException catch (e) {
    final d = e.details;
    final msg = d is Map ? d['error'] as String? : null;
    return InviteEmailResult.failed(msg ?? 'Could not send the email just now.');
  } catch (_) {
    return const InviteEmailResult.failed(
        'Could not send the email just now. Please check your connection and try again.');
  }
}

/// Tells the inviter by email that an invite was accepted (best effort, once per invite).
Future<void> notifyInviteAccepted(String token) async {
  try {
    await JamJotBackend.client.functions
        .invoke('notify-invite-accepted', body: {'token': token});
  } catch (_) {}
}

/// The "send it" window for every kind of invite: the person sending can edit the
/// email, send it straight from JamJot, and get a copy so they know it went out.
/// If email sending is not switched on yet, it offers Gmail / mail app / copy instead.
Future<void> showInviteMessageDialog(
  BuildContext context, {
  required String link,
  required String recipientName,
  required String subject,
  required String message,
  String initialEmail = '',
}) async {
  final token = inviteTokenFromLink(link);
  final email = TextEditingController(text: initialEmail);
  final subj = TextEditingController(text: subject);
  final body = TextEditingController(text: message);
  var copyMe = true;
  var busy = false;
  String? error;
  String? done;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> send() async {
          final to = email.text.trim();
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(to)) {
            setState(() => error = 'Please enter their email address.');
            return;
          }
          var text = body.text.trim();
          if (!text.contains(link)) text = '$text\n\n$link';
          setState(() {
            busy = true;
            error = null;
          });
          final r = await sendInviteEmail(
              token: token,
              toEmail: to,
              subject: subj.text.trim(),
              body: text,
              copyMe: copyMe);
          if (!dialogContext.mounted) return;
          if (r.sent) {
            setState(() {
              busy = false;
              done = r.copySent
                  ? 'Sent to $to! A copy is on its way to your inbox, and we\'ll email you when they accept.'
                  : 'Sent to $to! We\'ll email you when they accept.';
            });
          } else if (r.notConfigured) {
            setState(() => busy = false);
            await sendByEmail(dialogContext,
                to: to, subject: subj.text.trim(), body: text);
          } else {
            setState(() {
              busy = false;
              error = r.error;
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: Text(done == null ? 'Send the invite 🎉' : 'Invite sent ✅'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: done != null
                  ? Text(done!)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            'Here is a ready-written message for $recipientName. Change anything you like; just keep the link. The invite works for 30 days.'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Their email address'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: subj,
                          decoration:
                              const InputDecoration(labelText: 'Subject'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: body,
                          minLines: 7,
                          maxLines: 14,
                          decoration: const InputDecoration(
                              labelText: 'Message',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder()),
                        ),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                              'Email me a copy so I know it was sent'),
                          value: copyMe,
                          onChanged: (v) => setState(() => copyMe = v == true),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(error!,
                                style: const TextStyle(
                                    color: JamJotColors.recording)),
                          ),
                      ],
                    ),
            ),
          ),
          actions: [
            if (done == null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        var text = body.text.trim();
                        if (!text.contains(link)) text = '$text\n\n$link';
                        await Clipboard.setData(ClipboardData(text: text));
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text('Message copied!')));
                        }
                      },
                child: const Text('Copy message'),
              ),
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(done == null ? 'Close' : 'Done'),
            ),
            if (done == null)
              FilledButton.icon(
                onPressed: busy ? null : send,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
                label: const Text('Send email'),
                style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
              ),
          ],
        );
      },
    ),
  );
}
