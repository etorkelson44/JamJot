// Fictional local market. No requests leave this MockClient.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/widgets/fan_stage.dart';

const marketPreviewStudent = 'fictional-musician';

class MarketFixture {
  int coins = 75;
  bool failPurchase = false;
  int purchaseCalls = 0;
  final requests = <String, Map<String, dynamic>>{};
  final shelf = <Map<String, dynamic>>[];
  final student = <String, dynamic>{
    'id': marketPreviewStudent,
    'display_name': 'Melody',
    'instruments': ['Piano']
  };
  final items = <Map<String, dynamic>>[
    {
      'id': '163b9c5c-7f83-441d-8d0d-6a4b7de1e343',
      'stand': 'jamjot',
      'kind': 'avatar',
      'asset_key': 'jalapeno',
      'title': 'Pepper Presto',
      'description': 'A little spice. A whole lot of tempo.',
      'price': 25,
      'emoji': '🌶️'
    },
    {
      'id': '40855251-90de-4b40-9753-8c435e360f9b',
      'stand': 'jamjot',
      'kind': 'avatar',
      'asset_key': 'strawberry',
      'title': 'Rockstar Strawberry',
      'description': 'Previous catalog description',
      'price': 25,
      'emoji': '🍓'
    },
  ];
  void reset() {
    coins = 75;
    failPurchase = false;
    purchaseCalls = 0;
    requests.clear();
    shelf.clear();
    student.remove('avatar_key');
  }

  late final http.Client client = MockClient((request) async {
    http.Response reply(Object value, [int code = 200]) =>
        http.Response(jsonEncode(value), code,
            request: request, headers: {'content-type': 'application/json'});
    final path = request.url.path;
    if (request.method == 'GET') {
      if (path.endsWith('/market_items')) return reply(items);
      if (path.endsWith('/purchases')) return reply(shelf);
      if (path.endsWith('/berry_ledger')) {
        return reply([
          {'amount': coins}
        ]);
      }
      return reply([]);
    }
    final params = jsonDecode(request.body) as Map<String, dynamic>;
    if (params['p_student_id'] != marketPreviewStudent) {
      return reply(
          {'message': 'Unknown fictional child', 'code': '42501'}, 403);
    }
    if (path.endsWith('/rpc/purchase_market_item')) {
      purchaseCalls++;
      if (failPurchase) {
        return reply(
            {'message': 'Purchase unavailable', 'code': 'test_error'}, 400);
      }
      final key = params['p_request_id'] as String;
      if (requests.containsKey(key)) return reply(requests[key]!);
      final item = items.singleWhere((i) => i['id'] == params['p_item_id']);
      if (shelf.any((p) =>
          (p['market_items'] as Map)['asset_key'] == item['asset_key'])) {
        return reply({'ok': false, 'error': 'Already owned'});
      }
      if (coins < (item['price'] as int)) {
        return reply(
            {'ok': false, 'error': 'Not enough coins yet — keep practicing!'});
      }
      coins -= item['price'] as int;
      shelf.add({
        'id': 'purchase-${shelf.length}',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'fulfilled',
        'market_items': {...item}
      });
      student['avatar_key'] = item['asset_key'];
      final result = {'ok': true, 'new_balance': coins};
      requests[key] = result;
      return reply(result);
    }
    if (path.endsWith('/rpc/wear_owned_avatar')) {
      if (!shelf.any((p) =>
          (p['market_items'] as Map)['asset_key'] == params['p_asset_key'])) {
        return reply({'ok': false, 'error': 'Buy this avatar first'});
      }
      student['avatar_key'] = params['p_asset_key'];
      return reply({'ok': true});
    }
    return reply({'message': 'Local preview only', 'code': 'denied'}, 403);
  });
  List<Override> overrides() => [
        activeStudentProvider.overrideWith((ref) => {...student}),
        myStudentsProvider.overrideWith((ref) async => [
              {...student}
            ]),
        myProfileProvider.overrideWith((ref) async => null),
        myTeacherProvider.overrideWith((ref) async => null),
        myChatsProvider.overrideWith((ref) async => []),
        fanTotalProvider(marketPreviewStudent).overrideWith((ref) async => 0),
        weeklyFansProvider(marketPreviewStudent).overrideWith((ref) async => 0),
        currentLessonProvider(marketPreviewStudent)
            .overrideWith((ref) async => null),
      ];
}
