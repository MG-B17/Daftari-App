import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(AppDateUtils.initialize);

  test('localized dates and times', () {
    final date = DateTime(2026, 1, 2, 13, 5);
    expect(AppDateUtils.formatDate(date, locale: 'en'), 'Jan 2, 2026');
    expect(AppDateUtils.formatDate(date), contains('يناير'));
    expect(AppDateUtils.formatTime(date, locale: 'en'), '1:05\u202fPM');
    expect(AppDateUtils.formatTime(date), contains('م'));
  });

  test('relative day handles year/month boundaries and ignores time', () {
    final now = DateTime(2026, 1, 1, 0, 5);
    final yesterday = DateTime(2025, 12, 31, 23, 59);
    expect(AppDateUtils.isToday(DateTime(2026, 1, 1, 23), now: now), isTrue);
    expect(AppDateUtils.isYesterday(yesterday, now: now), isTrue);
    expect(AppDateUtils.relativeDay(now, now: now), 'اليوم');
    expect(AppDateUtils.relativeDay(yesterday, now: now), 'أمس');
    expect(AppDateUtils.relativeDay(now, now: now, locale: 'en'), 'Today');
    expect(
      AppDateUtils.relativeDay(yesterday, now: now, locale: 'en'),
      'Yesterday',
    );
    final older = DateTime(2025, 12, 30);
    expect(
      AppDateUtils.relativeDay(older, now: now, locale: 'en'),
      'Dec 30, 2025',
    );
    final tomorrow = DateTime(2026, 1, 2);
    expect(AppDateUtils.isYesterday(tomorrow, now: now), isFalse);
    expect(AppDateUtils.isToday(tomorrow, now: now), isFalse);
  });

  test('leap day and UTC timestamps compare in the local calendar', () {
    expect(
      AppDateUtils.isYesterday(
        DateTime(2024, 2, 29),
        now: DateTime(2024, 3, 1),
      ),
      isTrue,
    );
    final now = DateTime(2026, 7, 15, 10);
    expect(AppDateUtils.isToday(now.toUtc(), now: now), isTrue);
    expect(
      AppDateUtils.formatDate(now.toUtc(), locale: 'en'),
      AppDateUtils.formatDate(now, locale: 'en'),
    );
  });
}
