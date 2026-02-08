import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicebot/capabilities/web_host/document_image_store.dart';

void main() {
  group('DocumentImageStore', () {
    late Directory tempRoot;
    late DocumentImageStore store;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('voicebot_image_store_test_');
      store = DocumentImageStore(rootDirectory: tempRoot);
      await store.initialize();
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('save/list/read/delete image lifecycle works', () async {
      final bytes = Uint8List.fromList(List<int>.generate(32, (index) => index));
      final created = await store.saveImage(
        docName: 'doc_a.txt',
        fileName: 'sample.png',
        mimeType: 'image/png',
        bytes: bytes,
      );

      final imageId = (created['id'] ?? '').toString();
      expect(imageId.isNotEmpty, isTrue);

      final listed = await store.listImagesByDocument('doc_a.txt');
      expect(listed.length, 1);
      expect(listed.first['id'], imageId);

      final binary = await store.readImageBinary(imageId);
      expect(binary, isNotNull);
      expect(binary!.mimeType, 'image/png');
      expect(binary.bytes.length, bytes.length);

      final removed = await store.deleteImage(imageId);
      expect(removed, isTrue);
      final listedAfterDelete = await store.listImagesByDocument('doc_a.txt');
      expect(listedAfterDelete, isEmpty);
    });

    test('migrate document name keeps image mapping', () async {
      final bytes = Uint8List.fromList(List<int>.generate(24, (index) => index + 1));
      await store.saveImage(
        docName: 'old_doc.txt',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        bytes: bytes,
      );

      final moved = await store.migrateDocumentName(
        oldName: 'old_doc.txt',
        newName: 'new_doc.txt',
      );
      expect(moved, 1);

      final oldList = await store.listImagesByDocument('old_doc.txt');
      final newList = await store.listImagesByDocument('new_doc.txt');
      expect(oldList, isEmpty);
      expect(newList.length, 1);
    });

    test('clearDocument and clearAll remove metadata and files', () async {
      final bytes = Uint8List.fromList(List<int>.filled(48, 7));
      await store.saveImage(
        docName: 'doc_1.txt',
        fileName: 'one.webp',
        mimeType: 'image/webp',
        bytes: bytes,
      );
      await store.saveImage(
        docName: 'doc_2.txt',
        fileName: 'two.png',
        mimeType: 'image/png',
        bytes: bytes,
      );

      final removedDoc1 = await store.clearDocument('doc_1.txt');
      expect(removedDoc1, 1);
      expect(await store.listImagesByDocument('doc_1.txt'), isEmpty);
      expect((await store.listImagesByDocument('doc_2.txt')).length, 1);

      final removedAll = await store.clearAll();
      expect(removedAll, 1);
      expect(await store.listImagesByDocument('doc_2.txt'), isEmpty);
    });
  });
}
