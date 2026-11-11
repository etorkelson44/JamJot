// Helpers for how a caregiver is named in the family screens (JJ-054-C).
//
// "Known to (student) as" is stored in guardianships.display_name: what the
// student calls this caregiver (Dad, Grandpa Joe, Auntie Em). The
// relationship (Dad, Grandma, ...) is a separate, optional category.

/// A starting suggestion for the "Known to (student) as" box when the inviter
/// taps a relationship chip. They can always edit it.
String suggestKnownAs(String relation) {
  final r = relation.trim();
  if (r.isEmpty || r.contains('/')) return ''; // e.g. "Nanny / sitter"
  return r;
}

/// The " • Grandma" part shown after a caregiver's name. Empty when there is
/// no relationship or it only repeats the name ("Dad • Dad" would be noise).
String caregiverRoleSuffix(String shown, String relationship) {
  final rel = relationship.trim();
  if (rel.isEmpty) return '';
  if (shown.trim().toLowerCase() == rel.toLowerCase()) return '';
  return ' • $rel';
}
