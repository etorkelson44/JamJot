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
