import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/jamjot_theme.dart';
import 'page_nav.dart';

/// Which published version this copy of the app is. The Cloudflare build sets
/// it to the Git commit (see scripts/cloudflare-build.sh); it is empty when
/// running locally, which switches the update check off.
const String kBuildId = String.fromEnvironment('BUILD_ID');

/// True when a newer version than the one running has been published.
bool shouldOfferUpdate(String running, String? latest) {
  final l = (latest ?? '').trim();
  final r = running.trim();
  return r.isNotEmpty && l.isNotEmpty && r != l;
}

/// Asks the site which version is newest (build-id.txt is written at build time
/// and is never kept in the browser's cache). Null if it cannot be read.
Future<String?> fetchLatestBuildId() async {
  try {
    final uri = Uri.base
        .resolve('build-id.txt')
        .replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
    final res = await http
        .get(uri, headers: const {'Cache-Control': 'no-cache'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final body = res.body.trim();
    // A missing file can come back as the app's own page; ignore anything odd.
    if (body.isEmpty || body.length > 80 || body.contains('<')) return null;
    return body;
  } catch (_) {
    return null;
  }
}

/// Wraps the whole app. While someone has JamJot open, it checks every few
/// minutes (and whenever they come back to the tab) whether a newer version has
/// been published, and shows a small "tap to update" bar. It never reloads on
/// its own, so nobody loses something they are in the middle of typing.
class AppUpdateHost extends StatefulWidget {
  const AppUpdateHost({super.key, required this.child, this.runningBuildId = kBuildId});

  final Widget child;
  final String runningBuildId;

  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _available = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (widget.runningBuildId.isEmpty) return; // local run: nothing to compare
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
    Timer(const Duration(seconds: 20), _check);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_available || _checking || !mounted) return;
    _checking = true;
    final latest = await fetchLatestBuildId();
    _checking = false;
    if (!mounted) return;
    if (shouldOfferUpdate(widget.runningBuildId, latest)) {
      setState(() => _available = true);
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_available)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
                  side: JamJotShape.border,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                  child: Row(children: [
                    const Expanded(
                      child: Text('✨ A new version of JamJot is ready.',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _available = false),
                      child: const Text('Later'),
                    ),
                    FilledButton(
                      onPressed: reloadPage,
                      child: const Text('Update'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
