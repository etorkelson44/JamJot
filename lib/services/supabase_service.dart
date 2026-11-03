import 'package:supabase_flutter/supabase_flutter.dart';

/// JamJot's live backend. The publishable key is safe to ship in the app —
/// all real protection lives in the database's row-level security rules.
abstract final class JamJotBackend {
  static const url = 'https://cedlqxhrqwqwkohioiqb.supabase.co';
  static const publishableKey = 'sb_publishable_lyH9tNsBpULurK3XebPb5g_pZE1BcHe';

  static Future<void> init() async {
    await Supabase.initialize(url: url, anonKey: publishableKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
  static bool get signedIn => client.auth.currentSession != null;
}
