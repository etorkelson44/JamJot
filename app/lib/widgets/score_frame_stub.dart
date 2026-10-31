import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Non-web fallback: open the sheet music in the device's own viewer.
Widget buildScoreFrame(String url) {
  return Center(
    child: OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url)),
      icon: const Icon(Icons.open_in_new),
      label: const Text('Open sheet music'),
    ),
  );
}
