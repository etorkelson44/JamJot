import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/supabase_service.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/notestar_art.dart';
import '../../widgets/recording_player.dart';

/// What a Superfan sees from their album link (no account needed):
/// the kid's album with first and last takes, and a fan mail box.
class FanPageScreen extends StatefulWidget {
  const FanPageScreen({super.key, required this.token});
  final String token;
  @override
  State<FanPageScreen> createState() => _FanPageScreenState();
}

class _FanPageScreenState extends State<FanPageScreen> {
  static final _fn = Uri.parse('${JamJotBackend.url}/functions/v1/fan-page');
  Map<String, dynamic>? _album;
  String? _error;
  final _name = TextEditingController();
  final _msg = TextEditingController();
  bool _sending = false;
  String? _sentNote;

  Map<String, String> get _headers => {
        'apikey': JamJotBackend.publishableKey,
        'Authorization': 'Bearer ${JamJotBackend.publishableKey}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(_fn.replace(queryParameters: {'t': widget.token}), headers: _headers);
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) throw d['error'] ?? 'Not found';
      setState(() {
        _album = d;
        _name.text = (d['fan_name'] as String?) ?? '';
      });
    } catch (e) {
      setState(() => _error = e is String ? e : 'This album link could not be opened.');
    }
  }

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final r = await http.post(_fn,
          headers: _headers,
          body: jsonEncode({'t': widget.token, 'name': _name.text.trim(), 'message': _msg.text.trim()}));
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) throw d['error'] ?? 'error';
      setState(() {
        _msg.clear();
        _sentNote = d['needs_review'] == true
            ? 'Sent! A grown-up will pass it along to ${d['kid_name']}.'
            : 'Sent! ${d['kid_name']} will see it in their fan mail.';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e is String ? e : 'Could not send right now.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = _album;
    return Scaffold(
      backgroundColor: JamJotColors.marigold,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const StarBounce(size: 140, animate: false),
                      const SizedBox(height: 12),
                      Text(_error!, style: text.titleMedium, textAlign: TextAlign.center),
                    ]),
                  )
                : a == null
                    ? const Center(child: StarBounce(size: 140))
                    : ListView(padding: const EdgeInsets.all(20), children: [
                        Center(
                            child: Image.asset('assets/art/notestar_logo.png',
                                width: 90, semanticLabel: 'NoteStar')),
                        const SizedBox(height: 8),
                        Text('${a['kid_name']} made you an album!',
                            style: text.headlineSmall, textAlign: TextAlign.center),
                        Text(a['album_title'] as String? ?? '',
                            style: text.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                            'Hear how each song sounded at the start of the week, and how it sounds after a week of practice.',
                            style: text.bodyMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        for (final s in (a['songs'] as List).cast<Map>()) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: JamJotColors.ink, width: 2),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s['title'] as String, style: text.titleLarge),
                              if (s['first_url'] != null) ...[
                                const SizedBox(height: 8),
                                Text('First take', style: text.titleSmall),
                                RecordingPlayer(url: s['first_url'] as String),
                              ],
                              if (s['last_url'] != null) ...[
                                const SizedBox(height: 8),
                                Row(children: [
                                  const PaperAccent('star_big_pink', size: 22),
                                  const SizedBox(width: 6),
                                  Text('Last take', style: text.titleSmall),
                                ]),
                                RecordingPlayer(url: s['last_url'] as String),
                              ],
                            ]),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: JamJotColors.ink, width: 2),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text('Send ${a['kid_name']} fan mail', style: text.titleLarge),
                            const SizedBox(height: 8),
                            TextField(
                                controller: _name,
                                decoration: const InputDecoration(labelText: 'Your name')),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _msg,
                              maxLength: 1000,
                              minLines: 3,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                  labelText: 'Your note',
                                  hintText: 'I could hear how hard you worked on that song!'),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                                onPressed: _sending ? null : _send,
                                child: Text(_sending ? 'Sending…' : 'Send fan mail')),
                            if (_sentNote != null) ...[
                              const SizedBox(height: 8),
                              Text(_sentNote!, style: text.bodyMedium, textAlign: TextAlign.center),
                            ],
                          ]),
                        ),
                      ]),
          ),
        ),
      ),
    );
  }
}
