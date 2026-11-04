import 'package:blocodenotasturmab/utils/date_utils.dart';
import 'package:blocodenotasturmab/utils/id_generator.dart';
import 'package:blocodenotasturmab/utils/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeForSearch', () {
    test('remove acentos e converte para minúsculas', () {
      expect(normalizeForSearch('REUNIÃO às Três'), 'reuniao as tres');
      expect(normalizeForSearch('Coração Ç Ñ Ü'), 'coracao c n u');
    });

    test('trata acentos em forma decomposta', () {
      expect(normalizeForSearch('Reunião'), 'reuniao');
    });
  });

  test('escapeLike protege os caracteres especiais do LIKE', () {
    expect(escapeLike(r'50%_a\b'), r'50\%\_a\\b');
  });

  group('datas', () {
    test('parseLegacyDate lê o formato do banco antigo', () {
      final millis = parseLegacyDate('03/11/2026 21:15')!;
      expect(formatDateTime(millis), '03/11/2026 21:15');
    });

    test('parseLegacyDate rejeita outros formatos', () {
      expect(parseLegacyDate('ontem'), isNull);
    });

    test('nextTimestamp sempre avança', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1000);

      expect(nextTimestamp(null, now: now), 1000);
      expect(nextTimestamp(500, now: now), 1000);
      expect(nextTimestamp(1000, now: now), 1001);
      expect(nextTimestamp(5000, now: now), 5001);
    });
  });

  test('generateId gera UUIDs v4 sem repetição', () {
    final ids = List.generate(1000, (_) => generateId());

    expect(ids.toSet().length, 1000);
    expect(
      ids.first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
