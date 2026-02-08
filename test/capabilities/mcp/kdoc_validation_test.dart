import 'package:flutter_test/flutter_test.dart';

import 'package:voicebot/capabilities/mcp/mcp_server.dart';

void main() {
  group('KDOC validation', () {
    test('accepts a valid KDOC v1 document', () {
      const doc = '''
=== KDOC:v1 ===
[DOC_ID]
product_bot_chanh

[DOC_TYPE]
product

[TITLE]
Bột chanh Chavi

[ALIASES]
bột chanh | bot chanh | cha vi

[SUMMARY]
Mô tả ngắn

[CONTENT]
Nội dung chính

[LAST_UPDATED]
2026-02-08
=== END_KDOC ===
''';

      final result = LocalKnowledgeBase.validateKdocContent(doc);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects missing required sections', () {
      const doc = '''
=== KDOC:v1 ===
[DOC_ID]
doc_1

[DOC_TYPE]
product

[ALIASES]
abc

[SUMMARY]
Mô tả

[CONTENT]
Nội dung

[LAST_UPDATED]
2026-02-08
=== END_KDOC ===
''';

      final result = LocalKnowledgeBase.validateKdocContent(doc);
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('[TITLE]'));
    });

    test('rejects invalid DOC_TYPE', () {
      const doc = '''
=== KDOC:v1 ===
[DOC_ID]
doc_1

[DOC_TYPE]
unknown

[TITLE]
Tiêu đề

[ALIASES]
abc

[SUMMARY]
Mô tả

[CONTENT]
Nội dung

[LAST_UPDATED]
2026-02-08
=== END_KDOC ===
''';

      final result = LocalKnowledgeBase.validateKdocContent(doc);
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('DOC_TYPE'));
    });
  });
}

