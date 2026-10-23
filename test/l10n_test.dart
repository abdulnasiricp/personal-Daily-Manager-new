import 'package:flutter_test/flutter_test.dart';
import 'package:personal_daily_manager/l10n.dart';

void main() {
  tearDown(() => appLang.value = 'en');

  test('English is the default and fills placeholders', () {
    expect(appLang.value, 'en');
    expect(tr('Home'), 'Home');
    expect(tr('Pending ({n})', {'n': 3}), 'Pending (3)');
  });

  test('Urdu translates and still fills placeholders', () {
    appLang.value = 'ur';
    expect(tr('Home'), 'ہوم');
    expect(tr('Pending ({n})', {'n': 3}), 'زیر التوا (3)');
  });

  test('missing Urdu text falls back to English', () {
    appLang.value = 'ur';
    expect(tr('Some brand new text'), 'Some brand new text');
  });

  test('every Urdu entry keeps the same {placeholders} as its English key', () {
    final re = RegExp(r'\{[a-z]+\}');
    urduStrings.forEach((en, ur) {
      final a = re.allMatches(en).map((m) => m.group(0)).toSet();
      final b = re.allMatches(ur).map((m) => m.group(0)).toSet();
      expect(b, a, reason: en);
    });
  });
}
