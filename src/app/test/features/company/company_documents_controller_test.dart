import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/company/application/company_documents_controller.dart';

void main() {
  test('restore recharge les documents sauvegardés', () async {
    final storage = MemoryCompanyDocumentsStorage();
    await storage.save([
      const CompanyDocument(
        id: 'document-1',
        title: 'Contrat alternance',
        kind: 'Contrat',
        link: 'https://drive.example/contrat',
      ),
    ]);

    final controller = CompanyDocumentsController(storage: storage);
    await controller.restore();

    expect(controller.documents, hasLength(1));
    expect(controller.documents.single.title, 'Contrat alternance');
  });

  test('addDocument sauvegarde un nouveau document', () async {
    final storage = MemoryCompanyDocumentsStorage();
    final controller = CompanyDocumentsController(storage: storage);

    controller.addDocument(
      title: ' Contrat alternance ',
      kind: ' Contrat ',
      link: ' https://drive.example/contrat ',
    );

    final savedDocuments = await storage.read();
    expect(savedDocuments, hasLength(1));
    expect(savedDocuments.single.title, 'Contrat alternance');
    expect(savedDocuments.single.kind, 'Contrat');
    expect(savedDocuments.single.link, 'https://drive.example/contrat');
  });
}
