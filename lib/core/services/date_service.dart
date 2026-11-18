abstract interface class DateService {
  DateTime now();
}

class SystemDateService implements DateService {
  @override
  DateTime now() => DateTime.now();
}
