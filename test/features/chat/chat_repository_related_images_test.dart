import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicebot/capabilities/protocol/protocol.dart';
import 'package:voicebot/capabilities/web_host/local_web_host_service.dart';
import 'package:voicebot/capabilities/voice/session_coordinator.dart';
import 'package:voicebot/capabilities/voice/transport_client.dart';
import 'package:voicebot/features/chat/infrastructure/repositories/chat_repository_impl.dart';

void main() {
  group('ChatRepositoryImpl.getRelatedImagesForQuery', () {
    late ChatRepositoryImpl repository;
    late List<Map<String, dynamic>> requests;
    late Future<Map<String, dynamic>?> Function(Map<String, dynamic>)
    mockMcpHandle;

    setUp(() {
      requests = <Map<String, dynamic>>[];
      mockMcpHandle = (payload) async {
        requests.add(Map<String, dynamic>.from(payload));
        final params = payload['params'];
        final name = params is Map ? params['name'] : null;
        if (name == 'self.knowledge.search_images') {
          return <String, dynamic>{
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result': <String, dynamic>{
              'content': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'text',
                  'text': jsonEncode(<String, Object?>{
                    'query': 'bot chanh',
                    'matched_docs': 2,
                    'images': <Map<String, Object?>>[
                      <String, Object?>{
                        'id': 'img_1',
                        'doc_name': 'doc_a.txt',
                        'file_name': 'a.jpg',
                        'mime_type': 'image/jpeg',
                        'bytes': 200,
                        'created_at': '2026-02-08T00:00:00.000Z',
                        'score': 90,
                        'url': '/api/documents/image/content?id=img_1',
                      },
                      <String, Object?>{
                        'id': 'img_shared',
                        'doc_name': 'doc_a.txt',
                        'file_name': 'shared-a.jpg',
                        'mime_type': 'image/jpeg',
                        'bytes': 210,
                        'created_at': '2026-02-08T00:10:00.000Z',
                        'score': 75,
                        'url': '/api/documents/image/content?id=img_shared',
                      },
                      <String, Object?>{
                        'id': 'img_shared',
                        'doc_name': 'doc_b.txt',
                        'file_name': 'shared-b.jpg',
                        'mime_type': 'image/jpeg',
                        'bytes': 220,
                        'created_at': '2026-02-08T00:11:00.000Z',
                        'score': 60,
                        'url': '/api/documents/image/content?id=img_shared',
                      },
                    ],
                  }),
                },
              ],
              'isError': false,
            },
          };
        }
        return <String, dynamic>{
          'jsonrpc': '2.0',
          'id': payload['id'],
          'error': <String, dynamic>{'message': 'unknown tool'},
        };
      };

      repository = ChatRepositoryImpl(
        sessionCoordinator: _FakeSessionCoordinator(),
        webHostBaseUriResolver: () => Uri.parse('http://127.0.0.1:8080/'),
        mcpHandleMessage: mockMcpHandle,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test(
      'maps MCP search_images -> related images, deduplicates and respects maxImages',
      () async {
        final images = await repository.getRelatedImagesForQuery(
          'bot chanh',
          topK: 3,
          maxImages: 2,
        );

        expect(images.length, 2);
        expect(images[0].id, 'img_1');
        expect(images[1].id, 'img_shared');
        expect(images[0].score >= images[1].score, isTrue);
        expect(images[0].url.startsWith('http://127.0.0.1:8080/'), isTrue);
        expect(requests, isNotEmpty);
        final last = requests.last;
        final params = last['params'] as Map<String, dynamic>;
        final args = params['arguments'] as Map<String, dynamic>;
        expect(params['name'], 'self.knowledge.search_images');
        expect(args['query'], 'bot chanh');
        expect(args['top_k'], 3);
        expect(args['max_images'], 2);
      },
    );

    test(
      'uses loopback URI from web-host state when no resolver is injected',
      () async {
        repository.dispose();
        repository = ChatRepositoryImpl(
          sessionCoordinator: _FakeSessionCoordinator(),
          webHostStateResolver: () =>
              const LocalWebHostState.running(ip: '192.168.1.25', port: 9090),
          mcpHandleMessage: mockMcpHandle,
        );

        final images = await repository.getRelatedImagesForQuery(
          'bot chanh',
          topK: 3,
          maxImages: 1,
        );

        expect(images, hasLength(1));
        expect(
          images.first.url,
          'http://127.0.0.1:9090/api/documents/image/content?id=img_1',
        );
      },
    );

    test('returns empty list when MCP tool fails', () async {
      repository.dispose();
      repository = ChatRepositoryImpl(
        sessionCoordinator: _FakeSessionCoordinator(),
        webHostBaseUriResolver: () => Uri.parse('http://127.0.0.1:8080/'),
        mcpHandleMessage: (payload) async => <String, dynamic>{
          'jsonrpc': '2.0',
          'id': payload['id'],
          'error': <String, dynamic>{'message': 'tool failed'},
        },
      );

      final images = await repository.getRelatedImagesForQuery(
        'query',
        topK: 2,
        maxImages: 4,
      );
      expect(images, isEmpty);
    });

    test(
      'returns only direct document images when knowledge-aligned images exist',
      () async {
        requests.clear();
        repository.dispose();
        repository = ChatRepositoryImpl(
          sessionCoordinator: _FakeSessionCoordinator(),
          webHostBaseUriResolver: () => Uri.parse('http://127.0.0.1:8080/'),
          mcpHandleMessage: (payload) async {
            requests.add(Map<String, dynamic>.from(payload));
            final params = payload['params'];
            final name = params is Map ? params['name'] : null;
            final arguments = params is Map<String, dynamic>
                ? params['arguments'] as Map<String, dynamic>?
                : null;
            if (name == 'self.knowledge.search') {
              return _toolResult(payload['id'], <String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'company_profile_177.txt',
                    'title': 'Công ty Chanh Việt',
                    'score': 88,
                  },
                ],
              });
            }
            if (name == 'self.knowledge.list_images') {
              final docName = (arguments?['doc_name'] ?? '').toString();
              if (docName == 'Công ty Chanh Việt') {
                return _toolResult(payload['id'], <String, Object?>{
                  'images': <Map<String, Object?>>[
                    <String, Object?>{
                      'id': 'img_doc',
                      'doc_name': 'Công ty Chanh Việt',
                      'file_name': 'doc.jpg',
                      'mime_type': 'image/jpeg',
                      'bytes': 120,
                      'created_at': '2026-03-15T00:00:00.000Z',
                      'url': '/api/documents/image/content?id=img_doc',
                    },
                  ],
                });
              }
              return _toolResult(payload['id'], <String, Object?>{
                'images': <Map<String, Object?>>[],
              });
            }
            if (name == 'self.knowledge.search_images') {
              return _toolResult(payload['id'], <String, Object?>{
                'images': <Map<String, Object?>>[
                  <String, Object?>{
                    'id': 'img_search',
                    'doc_name': 'Công ty Chanh Việt',
                    'file_name': 'search.jpg',
                    'mime_type': 'image/jpeg',
                    'bytes': 140,
                    'created_at': '2026-03-15T00:10:00.000Z',
                    'score': 95,
                    'url': '/api/documents/image/content?id=img_search',
                  },
                ],
              });
            }
            return _toolError(payload['id'], 'unknown tool');
          },
        );

        final images = await repository.getRelatedImagesForQuery(
          'định hướng phát triển',
          topK: 3,
          maxImages: 4,
        );

        expect(images, hasLength(1));
        expect(images.first.id, 'img_doc');
        expect(
          requests.any((request) {
            final params = request['params'] as Map<String, dynamic>?;
            return params?['name'] == 'self.knowledge.search_images';
          }),
          isFalse,
        );
      },
    );
  });
}

Map<String, dynamic> _toolResult(Object? id, Map<String, Object?> payload) {
  return <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'result': <String, dynamic>{
      'content': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': jsonEncode(payload)},
      ],
      'isError': false,
    },
  };
}

Map<String, dynamic> _toolError(Object? id, String message) {
  return <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'error': <String, dynamic>{'message': message},
  };
}

class _FakeSessionCoordinator implements SessionCoordinator {
  final StreamController<Map<String, dynamic>> _incomingJsonController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _incomingAudioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _incomingLevelController =
      StreamController<double>.broadcast();
  final StreamController<double> _outgoingLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> _errorsController =
      StreamController<String>.broadcast();
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  @override
  Stream<Map<String, dynamic>> get incomingJson =>
      _incomingJsonController.stream;

  @override
  Stream<Uint8List> get incomingAudio => _incomingAudioController.stream;

  @override
  Stream<double> get incomingLevel => _incomingLevelController.stream;

  @override
  Stream<double> get outgoingLevel => _outgoingLevelController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Stream<bool> get speaking => _speakingController.stream;

  @override
  int get serverSampleRate => 16000;

  @override
  ListeningMode get listeningMode => ListeningMode.autoStop;

  @override
  void setPlaybackSuppressed(bool suppressed) {}

  @override
  Future<bool> connect(TransportClient transport) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> playChime() async {}

  @override
  Future<void> sendAudio(List<int> data) async {}

  @override
  Future<void> sendText(String text) async {}

  @override
  Future<void> startListening({bool enableMic = true}) async {}

  @override
  Future<void> stopListening() async {}

  @override
  void setListeningMode(ListeningMode mode) {}
}
