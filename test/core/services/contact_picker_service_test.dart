import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/services/contact_picker_service.dart';
import 'package:daftariapp/features/customers/domain/entities/picked_contact.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancel returns null', () async {
    expect(
      await ContactPickerService(pickContact: () async => null).pickContact(),
      isNull,
    );
  });

  test('takes first nonempty normalized phone', () async {
    final service = ContactPickerService(
      pickContact: () async => Contact(
        fullName: '  Ahmed  ',
        phoneNumbers: [' ( ) ', ' +٢٠ ١٠-١٢٣٤ ٥٦٧٨ ', '01112345678'],
      ),
    );
    expect(
      await service.pickContact(),
      const PickedContact(name: 'Ahmed', phone: '+201012345678'),
    );
  });

  test('missing values are retained as null', () async {
    expect(
      await ContactPickerService(pickContact: () async => Contact())
          .pickContact(),
      const PickedContact(name: null, phone: null),
    );
  });

  test('platform errors are converted without exposing details', () async {
    final service = ContactPickerService(
      pickContact: () async => throw PlatformException(code: 'private'),
    );
    await expectLater(
      service.pickContact(),
      throwsA(isA<ContactPickerException>()),
    );
  });
}
