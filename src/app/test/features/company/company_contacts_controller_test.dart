import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/company/application/company_contacts_controller.dart';

void main() {
  test('restore recharge les contacts sauvegardés', () async {
    final storage = MemoryCompanyContactsStorage();
    await storage.save([
      const CompanyContact(
        id: 'contact-1',
        name: 'Marie Martin',
        role: 'Tutrice',
        email: 'marie@entreprise.fr',
      ),
    ]);

    final controller = CompanyContactsController(storage: storage);
    await controller.restore();

    expect(controller.contacts, hasLength(1));
    expect(controller.contacts.single.name, 'Marie Martin');
  });

  test('addContact sauvegarde un nouveau contact', () async {
    final storage = MemoryCompanyContactsStorage();
    final controller = CompanyContactsController(storage: storage);

    controller.addContact(
      name: ' Marie Martin ',
      role: ' Tutrice ',
      email: ' marie@entreprise.fr ',
    );

    final savedContacts = await storage.read();
    expect(savedContacts, hasLength(1));
    expect(savedContacts.single.name, 'Marie Martin');
    expect(savedContacts.single.role, 'Tutrice');
    expect(savedContacts.single.email, 'marie@entreprise.fr');
  });
}
