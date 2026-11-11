import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/services/app_update.dart';

void main() {
  test('offers an update only when both versions are known and differ', () {
    expect(shouldOfferUpdate('abc', 'def'), true);
    expect(shouldOfferUpdate('abc', 'abc'), false);
    expect(shouldOfferUpdate('abc', 'abc\n'), false);
    expect(shouldOfferUpdate('', 'def'), false); // local run
    expect(shouldOfferUpdate('abc', null), false); // could not check
    expect(shouldOfferUpdate('abc', ''), false);
  });
}
