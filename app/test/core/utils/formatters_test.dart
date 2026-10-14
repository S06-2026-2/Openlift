// Formatadores de exibição e leitura tolerante de JSON.

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/utils/formatters.dart';
import 'package:openlift/core/utils/json_utils.dart';

void main() {
  group('formatters', () {
    test('formatDateBr', () {
      expect(formatDateBr(DateTime(2026, 1, 5)), '05/01/2026');
      expect(formatDateBr(DateTime(2026, 10, 13)), '13/10/2026');
    });

    test('formatNumber tira casa decimal inútil e usa vírgula', () {
      expect(formatNumber(60), '60');
      expect(formatNumber(62.5), '62,5');
    });

    test('formatKg usa milhar com ponto', () {
      expect(formatKg(0), '0 kg');
      expect(formatKg(500), '500 kg');
      expect(formatKg(1280), '1.280 kg');
      expect(formatKg(1234567.5), '1.234.567,5 kg');
    });
  });

  group('json_utils', () {
    test('asDouble aceita número, string e vírgula', () {
      expect(asDouble(60), 60.0);
      expect(asDouble('62.50'), 62.5);
      expect(asDouble('62,5'), 62.5);
      expect(asDouble('x'), isNull);
      expect(asDouble(null), isNull);
    });

    test('asInt aceita int, num e string', () {
      expect(asInt(8), 8);
      expect(asInt(8.0), 8);
      expect(asInt('8'), 8);
      expect(asInt('oito'), isNull);
    });

    test('parseApiDate e toApiDate fazem ida e volta', () {
      expect(parseApiDate('2026-10-13'), DateTime(2026, 10, 13));
      expect(parseApiDate('2026-10-13T08:00:00Z'), DateTime(2026, 10, 13));
      expect(parseApiDate('13/10/2026'), isNull);
      expect(toApiDate(DateTime(2026, 3, 9)), '2026-03-09');
    });
  });
}
