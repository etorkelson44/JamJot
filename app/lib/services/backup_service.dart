import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

abstract class BackupGateway {
  String? get accountId;
  bool get isPreview => false;
  Future<Uint8List> download(String password);
}

class ServerBackupGateway extends BackupGateway {
  @override
  String? get accountId => JamJotBackend.client.auth.currentUser?.id;
  @override
  Future<Uint8List> download(String password) async {
    final session = JamJotBackend.client.auth.currentSession;
    if (session == null) throw Exception('Please sign in again.');
    final response = await http
        .post(
          Uri.parse('${JamJotBackend.url}/functions/v1/export-data'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'apikey': JamJotBackend.publishableKey,
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(minutes: 3));
    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw Exception(
            'Backup is not available on this server yet. Your data has not changed.');
      }
      String message =
          'The complete backup could not be prepared. Please try again.';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
    final bytes = response.bodyBytes;
    if (accountId != session.user.id ||
        !((response.headers['content-type'] ?? '')
            .contains('application/zip')) ||
        bytes.length < 4 ||
        bytes[0] != 80 ||
        bytes[1] != 75) {
      throw Exception('The backup could not be verified. Please try again.');
    }
    return bytes;
  }
}

final backupGatewayProvider =
    Provider<BackupGateway>((ref) => ServerBackupGateway());
final canExportDataProvider = FutureProvider.autoDispose<bool>((ref) async {
  final client = JamJotBackend.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;
  final scopes = await Future.wait([
    client.from('guardianships').select('id').eq('profile_id', uid).limit(1),
    client.from('teachers').select('id').eq('profile_id', uid).limit(1),
    client.from('studios').select('id').eq('owner_id', uid).limit(1),
  ]);
  return scopes.any((rows) => rows.isNotEmpty);
});

class BackupPreferences {
  const BackupPreferences(
      {this.intervalDays = 0, this.lastSaved, this.dismissedUntil});
  final int intervalDays;
  final DateTime? lastSaved;
  final DateTime? dismissedUntil;
  bool due(DateTime now) =>
      intervalDays > 0 &&
      (dismissedUntil == null || !now.isBefore(dismissedUntil!)) &&
      (lastSaved == null ||
          !now.isBefore(lastSaved!.add(Duration(days: intervalDays))));
  static String key(String account) => 'jamjot.backup.v1.$account';
  static Future<BackupPreferences> read(String account) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final data = jsonDecode(prefs.getString(key(account)) ?? '{}') as Map;
      final interval = data['interval_days'];
      return BackupPreferences(
        intervalDays: [0, 7, 30, 90].contains(interval) ? interval as int : 0,
        lastSaved: DateTime.tryParse(data['last_saved'] as String? ?? ''),
        dismissedUntil:
            DateTime.tryParse(data['dismissed_until'] as String? ?? ''),
      );
    } catch (_) {
      return const BackupPreferences();
    }
  }

  Future<void> save(String account) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
        key(account),
        jsonEncode({
          'interval_days': intervalDays,
          'last_saved': lastSaved?.toUtc().toIso8601String(),
          'dismissed_until': dismissedUntil?.toUtc().toIso8601String(),
        }));
    if (!ok) {
      throw Exception('Could not save the reminder setting on this device.');
    }
  }
}

final backupPreferencesProvider = FutureProvider.autoDispose
    .family<BackupPreferences, String>(
        (ref, account) => BackupPreferences.read(account));
