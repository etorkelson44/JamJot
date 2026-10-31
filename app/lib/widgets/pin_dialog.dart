import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';

/// Asks for a 4-digit PIN and checks it against [pinHash].
/// Returns true if correct (or dismissed with success), false/null otherwise.
Future<bool> askForPin(BuildContext context,
    {required String title, required String pinHash}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => _PinDialog(title: title, pinHash: pinHash),
  );
  return ok ?? false;
}

/// Asks for a new 4-digit PIN (typed twice). Returns it, or null if cancelled.
Future<String?> askForNewPin(BuildContext context,
    {required String title}) async {
  final first = TextEditingController();
  final second = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                  counterText: '', hintText: '4 digits'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: second,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                  counterText: '', hintText: 'same 4 digits again'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!,
                    style: const TextStyle(color: JamJotColors.recording)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (first.text.trim().length != 4) {
                setState(() => error = 'The PIN needs exactly 4 digits.');
                return;
              }
              if (first.text.trim() != second.text.trim()) {
                setState(() => error = 'Those two do not match.');
                return;
              }
              Navigator.of(context).pop(first.text.trim());
            },
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, required this.pinHash});

  final String title;
  final String pinHash;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _check() {
    if (hashPin(_pin.text.trim()) == widget.pinHash) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        side: JamJotShape.border,
      ),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(counterText: ''),
            onSubmitted: (_) => _check(),
          ),
          if (_wrong)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Hmm, that is not it. Try again!',
                  style: TextStyle(color: JamJotColors.recording)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _check,
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
