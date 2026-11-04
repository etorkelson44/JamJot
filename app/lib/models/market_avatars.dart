/// Founder-supplied temporary character art; keys stay stable when art changes.
const musicalAvatars =
    <String, ({String name, String description, String emoji})>{
  'jalapeno': (
    name: 'Pepper Presto',
    description: 'A little spice. A whole lot of tempo.',
    emoji: '🌶️'
  ),
  'strawberry': (
    name: 'Berry Bebop',
    description: 'Sweet moves and jazzy grooves.',
    emoji: '🍓'
  ),
  'grape': (
    name: 'Gracie Grace Note',
    description: 'A whole bunch of harmony.',
    emoji: '🍇'
  ),
  'lemon': (
    name: 'Lenny Legato',
    description: 'A little zest. A smooth melody.',
    emoji: '🍋'
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
