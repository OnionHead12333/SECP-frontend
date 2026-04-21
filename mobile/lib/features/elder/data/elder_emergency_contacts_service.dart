import '../../../core/config/app_config.dart';
import '../models/elder_emergency_contact.dart';
import '../models/elder_mock_emergency_contact.dart';
import 'elder_emergency_contacts_api.dart';
import 'elder_mock_auth_service.dart';

final class ElderEmergencyContactsService {
  ElderEmergencyContactsService._();

  static Future<List<ElderEmergencyContact>> fetchContacts({required String elderPhone}) async {
    if (AppConfig.useMockEmergencyContacts) {
      final contacts = await ElderMockAuthService.emergencyContactsForPhone(elderPhone);
      return contacts.map(_fromMock).toList();
    }
    return ElderEmergencyContactsApi.fetchContacts(elderPhone: elderPhone);
  }

  static Future<List<ElderEmergencyContact>> addContact({
    required String elderPhone,
    required String name,
    required String relation,
    required String contactPhone,
    required String note,
    required bool makePrimary,
  }) async {
    if (AppConfig.useMockEmergencyContacts) {
      final contacts = await ElderMockAuthService.addEmergencyContact(
        phone: elderPhone,
        name: name,
        relation: relation,
        contactPhone: contactPhone,
        note: note,
        makePrimary: makePrimary,
      );
      return contacts.map(_fromMock).toList();
    }
    return ElderEmergencyContactsApi.addContact(
      elderPhone: elderPhone,
      name: name,
      relation: relation,
      contactPhone: contactPhone,
      note: note,
      makePrimary: makePrimary,
    );
  }

  static ElderEmergencyContact _fromMock(ElderMockEmergencyContact contact) {
    return ElderEmergencyContact(
      id: contact.id,
      name: contact.name,
      relation: contact.relation,
      phone: contact.phone,
      isPrimary: contact.isPrimary,
      note: contact.note,
    );
  }
}
