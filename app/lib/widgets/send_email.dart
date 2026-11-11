import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a ready-written email. A bare "mailto:" link does nothing useful in a
/// browser that has no mail program set up (it just opens a blank tab), so on
/// the web we offer Gmail's compose window too, and always a copy fallback.
Future<void> sendByEmail(BuildContext context,
    {String to = '', required String subject, required String body}) async {
  final mailto = Uri(
    scheme: 'mailto',
    path: to,
    query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  if (!kIsWeb) {
    await launchUrl(mailto);
    return;
  }
  final gmail = Uri.https('mail.google.com', '/mail/', {
    'view': 'cm',
    'fs': '1',
    if (to.isNotEmpty) 'to': to,
    'su': subject,
    'body': body,
  });
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Send with…'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await launchUrl(gmail);
            },
            icon: const Icon(Icons.email_outlined),
            label: const Text('Gmail'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await launchUrl(mailto, webOnlyWindowName: '_self');
            },
            icon: const Icon(Icons.mail_outline),
            label: const Text('My computer\'s mail app'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied!')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Just copy the message'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel')),
      ],
    ),
  );
}
