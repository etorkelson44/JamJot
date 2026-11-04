import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import '../state/coin_rewards.dart';
import 'coin_pouch.dart';

/// One listener above the router prevents duplicate sounds from retained tabs
/// and keeps rewards visible even when a completion dialog covers the header.
class CoinRewardHost extends ConsumerStatefulWidget {
  const CoinRewardHost(
      {super.key, required this.child, this.pollForUpdates = true});
  final Widget child;
  final bool pollForUpdates;
  @override
  ConsumerState<CoinRewardHost> createState() => _CoinRewardHostState();
}

class _CoinRewardHostState extends ConsumerState<CoinRewardHost>
    with WidgetsBindingObserver {
  final _tracker = CoinRewardTracker();
  Timer? _hide, _refresh;
  String? _studentId;
  int _earned = 0, _sequence = 0;
  bool _visible = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.pollForUpdates) {
      _refresh =
          Timer.periodic(const Duration(seconds: 45), (_) => _refreshBalance());
    }
  }

  void _refreshBalance() {
    final sid = ref.read(activeStudentProvider)?['id'] as String?;
    if (_visible &&
        sid != null &&
        !ref.read(berryBalanceProvider(sid)).isLoading) {
      ref.invalidate(berryBalanceProvider(sid));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (_visible && widget.pollForUpdates) _refreshBalance();
  }

  void _celebrate(String sid, int amount) {
    if (!mounted || !_visible || sid != ref.read(activeStudentProvider)?['id'])
      return;
    _hide?.cancel();
    setState(() {
      _earned += amount;
      _sequence++;
    });
    if (ref.read(coinSoundsProvider)) ref.read(coinSoundPlayerProvider)();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _earned = 0);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sid = ref.watch(activeStudentProvider)?['id'] as String?;
    ref.watch(coinSoundsProvider); // Load saved preference before any reward.
    if (sid != _studentId) {
      _studentId = sid;
      _earned = 0;
      _hide?.cancel();
    }
    final balance =
        sid == null ? null : ref.watch(berryBalanceProvider(sid)).valueOrNull;
    final delta = _tracker.observe(sid, balance);
    if (sid != null && delta > 0) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _celebrate(sid, delta));
    }
    final text = Theme.of(context).textTheme;
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (sid != null && _earned > 0)
        Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Semantics(
                  liveRegion: true,
                  label: '$_earned coins earned',
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.outline)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
                          child: Row(children: [
                            FallingCoinJar(
                                key: ValueKey(_sequence),
                                animate:
                                    !MediaQuery.disableAnimationsOf(context),
                                size: 96),
                            const SizedBox(width: 10),
                            Expanded(
                                child: ExcludeSemantics(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                  Text('+$_earned coins!',
                                      style: text.titleLarge),
                                  Text('A little more jam in your jar.',
                                      style: text.bodyMedium),
                                ]))),
                            Semantics(
                                label: 'Dismiss coin reward',
                                button: true,
                                child: IconButton(
                                    onPressed: () {
                                      _hide?.cancel();
                                      setState(() => _earned = 0);
                                    },
                                    icon: const Icon(Icons.close, size: 18))),
                          ])),
                    ),
                  ),
                ),
              ),
            )),
    ]);
  }
}
