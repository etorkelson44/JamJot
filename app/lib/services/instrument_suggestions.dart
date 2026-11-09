/// Typed-in instruments become suggestions the team reviews (JJ-036-C).
///
/// STUB — pending founder approval of the private instrument_suggestions
/// table (add-only, no student names or ids). Until it is approved this
/// does nothing: the typed instrument is still saved on the kid's own
/// profile, and nothing is sent anywhere.
class InstrumentSuggestions {
  /// Called only after the student taps "Yes, add it".
  static Future<void> submit(String tidyName) async {
    // TODO(JJ-036-C): call the approved suggest_instrument RPC here.
  }
}
