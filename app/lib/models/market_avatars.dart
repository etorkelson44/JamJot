/// The band: founder's photo-real bodies with drawn faces (JJ-012), named
/// with the founder's workshopped music puns (2026-11-04). Keys stay stable
/// when art changes.
const musicalAvatars =
    <String, ({String name, String description, String emoji})>{
  'strawberry': (
    name: 'Ms. Straw-ccato',
    description: 'Short and sweet!',
    emoji: '🍓'
  ),
  'jalapeno': (
    name: 'Señor Jalapresto',
    description: 'As fast as it gets. As hot as it gets.',
    emoji: '🌶️'
  ),
  'kiwi': (
    name: 'Keywi',
    description: 'Fresh, fuzzy and ready to play.',
    emoji: '🥝'
  ),
  'grape': (
    name: 'Grape Arpeggio',
    description: 'A bunch of notes, climbing.',
    emoji: '🍇'
  ),
  'lemon': (
    name: 'Lemon Sharp',
    description: 'Not sour — sharp. L♯.',
    emoji: '🍋'
  ),
  'raspberry': (
    name: 'Raspberry Rhapsody',
    description: 'One berry, a thousand notes.',
    emoji: '🫐'
  ),
};

Map<String, dynamic> presentMarketAvatar(Map<String, dynamic> item) {
  final character = musicalAvatars[item['asset_key']];
  if (character == null ||
      item['kind'] != 'avatar' ||
      item['stand'] != 'jamjot') {
    return item;
  }
  return {
    ...item,
    'title': character.name,
    'description': character.description
  };
}

/// Catalog previews never supply a purchasable server ID. After the catalog
/// migration, the real server row is used unchanged (including its price/ID).
List<Map<String, dynamic>> presentMarketItems(List<Map<String, dynamic>> rows,
    {bool includeUpcoming = false}) {
  final result = rows.map(presentMarketAvatar).toList();
  if (includeUpcoming) {
    for (final entry in musicalAvatars.entries) {
      if (result.any((r) =>
          r['stand'] == 'jamjot' &&
          r['kind'] == 'avatar' &&
          r['asset_key'] == entry.key)) {
        continue;
      }
      result.add({
        'id': 'upcoming-${entry.key}',
        'stand': 'jamjot',
        'kind': 'avatar',
        'asset_key': entry.key,
        'title': entry.value.name,
        'description': entry.value.description,
        'emoji': entry.value.emoji,
        'price': 25,
        'upcoming': true
      });
    }
  }
  return result;
}
