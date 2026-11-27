import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import '../../../features/customers/domain/entities/picked_contact.dart';
import '../../errors/app_exception.dart';
import '../../extensions/string_extensions.dart';

class ContactPickerService {
  ContactPickerService({Future<Contact?> Function()? pickContact})
    : _pickContact = pickContact ?? FlutterNativeContactPicker().selectContact;

  final Future<Contact?> Function() _pickContact;

  Future<PickedContact?> pickContact() async {
    try {
      final contact = await _pickContact();
      if (contact == null) return null;
      String? phone;
      for (final number in contact.phoneNumbers ?? const <String>[]) {
        final normalized = number.toWesternDigits.replaceAll(
          RegExp(r'[^0-9+]'),
          '',
        );
        if (normalized.replaceAll('+', '').isNotEmpty) {
          phone = normalized;
          break;
        }
      }
      return PickedContact(name: contact.fullName?.nullIfBlank, phone: phone);
    } on PlatformException {
      throw const ContactPickerException();
    }
  }
}
