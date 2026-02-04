import 'dart:async';
import 'dart:convert';

import '../../../../capabilities/voice/session_coordinator.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';

class XiaozhiTextService {
  XiaozhiTextService({
    required SessionCoordinator sessionCoordinator,
    required String Function() sessionIdProvider,
    Duration sessionWaitTimeout = const Duration(seconds: 1),
  })  : _sessionCoordinator = sessionCoordinator,
        _sessionIdProvider = sessionIdProvider,
        _sessionWaitTimeout = sessionWaitTimeout;

  final SessionCoordinator _sessionCoordinator;
  final String Function() _sessionIdProvider;
  final Duration _sessionWaitTimeout;

  Future<Result<bool>> sendTextRequest(
    String text, {
    bool useTextType = false,
  }) async {
    final sessionId = await _resolveSessionId();
    final payload = useTextType
        ? <String, dynamic>{
            'type': 'text',
            'text': text,
            'session_id': sessionId,
          }
        : <String, dynamic>{
            'type': 'listen',
            'state': 'detect',
            'text': text,
            'source': 'text',
            'session_id': sessionId,
          };
    final encoded = jsonEncode(payload);
    AppLogger.event(
      'ChatRepository',
      'send_text',
      fields: <String, Object?>{
        'payload': encoded,
      },
    );
    await _sessionCoordinator.sendText(encoded);
    return Result.success(true);
  }

  Future<String> _resolveSessionId() async {
    final current = _sessionIdProvider();
    if (current.isNotEmpty) {
      return current;
    }
    final deadline = DateTime.now().add(_sessionWaitTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final next = _sessionIdProvider();
      if (next.isNotEmpty) {
        return next;
      }
    }
    return _sessionIdProvider();
  }
}
