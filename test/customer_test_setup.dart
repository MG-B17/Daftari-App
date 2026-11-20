import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<AppDatabase> setupCustomerTests({bool seed = true}) async {
  await sl.reset();
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final database = AppDatabase(NativeDatabase.memory());
  sl.registerSingleton<AppDatabase>(database, dispose: (db) => db.close());
  await configureDependencies();
  if (seed) {
    final first = await database.customerDao.createCustomer(
      name: 'Mohamed Abdel Fattah',
      phone: '01012345678',
    );
    await database.customerDao.createCustomer(
      name: 'Ahmed El Shenawy',
      phone: '01124567890',
    );
    await database.customerDao.createCustomer(
      name: 'Umm Karim',
      phone: '01155443322',
    );
    await database.transactionDao.createTransaction(
      customerId: first.id,
      type: TransactionTypes.credit,
      amountPiasters: 320000,
    );
  }
  return database;
}
