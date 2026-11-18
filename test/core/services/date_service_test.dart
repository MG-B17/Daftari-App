import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDateService implements DateService {
  FakeDateService(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => sl.reset());

  test('system service returns the current time', () {
    final before = DateTime.now();
    final actual = SystemDateService().now();
    final after = DateTime.now();
    expect(actual.isBefore(before), isFalse);
    expect(actual.isAfter(after), isFalse);
  });

  test('bootstrap preserves an injected deterministic service', () async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    final fake = FakeDateService(DateTime(2020, 2, 3, 4, 5));
    sl.registerSingleton<DateService>(fake);

    await configureDependencies();

    expect(sl<DateService>(), same(fake));
    expect(sl<DateService>().now(), DateTime(2020, 2, 3, 4, 5));
  });
}
