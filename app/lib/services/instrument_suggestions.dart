import 'supabase_service.dart';

/// Typed-in instruments become suggestions the team reviews (JJ-036-C).
///
/// Sends only the cleaned instrument name to the private
/// instrument_suggestions store (add-only; no student names or ids; kids
/// and families cannot read it). Called only after "Yes, add it".
class InstrumentSuggestions {
  static Future<void> submit(String tidyName) async {
    try {
      await JamJotBackend.client
          .rpc('suggest_instrument', params: {'p_name': tidyName});
    } catch (_) {
      // A missed suggestion never blocks adding the instrument.
    }
  }
}
