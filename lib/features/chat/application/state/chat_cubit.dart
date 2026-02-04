import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../capabilities/protocol/protocol.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/debounce.dart';
import '../../../../core/utils/throttle.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_response.dart';
import '../usecases/connect_chat_usecase.dart';
import '../usecases/disconnect_chat_usecase.dart';
import '../usecases/load_chat_config_usecase.dart';
import '../usecases/observe_chat_errors_usecase.dart';
import '../usecases/observe_chat_incoming_level_usecase.dart';
import '../usecases/observe_chat_outgoing_level_usecase.dart';
import '../usecases/observe_chat_responses_usecase.dart';
import '../usecases/observe_chat_speaking_usecase.dart';
import '../usecases/send_chat_message_usecase.dart';
import '../usecases/set_listening_mode_usecase.dart';
import '../usecases/start_listening_usecase.dart';
import '../usecases/stop_listening_usecase.dart';
import '../../domain/entities/chat_config.dart';
import 'chat_state.dart';
import 'chat_session.dart';

class ChatCubit extends Cubit<ChatState> implements ChatSession {
  ChatCubit({
    required LoadChatConfigUseCase loadConfig,
    required ConnectChatUseCase connect,
    required DisconnectChatUseCase disconnect,
    required SendChatMessageUseCase sendMessage,
    required StartListeningUseCase startListening,
    required StopListeningUseCase stopListening,
    required ObserveChatResponsesUseCase observeResponses,
    required ObserveChatErrorsUseCase observeErrors,
    required ObserveChatIncomingLevelUseCase observeIncomingLevel,
    required ObserveChatOutgoingLevelUseCase observeOutgoingLevel,
    required ObserveChatSpeakingUseCase observeSpeaking,
    required SetListeningModeUseCase setListeningMode,
  })  : _loadConfig = loadConfig,
        _connect = connect,
        _disconnect = disconnect,
        _sendMessage = sendMessage,
        _startListening = startListening,
        _stopListening = stopListening,
        _setListeningMode = setListeningMode,
        _observeResponses = observeResponses,
        _observeErrors = observeErrors,
        _observeIncomingLevel = observeIncomingLevel,
        _observeOutgoingLevel = observeOutgoingLevel,
        _observeSpeaking = observeSpeaking,
        super(ChatState.initial());

  final LoadChatConfigUseCase _loadConfig;
  final ConnectChatUseCase _connect;
  final DisconnectChatUseCase _disconnect;
  final SendChatMessageUseCase _sendMessage;
  final StartListeningUseCase _startListening;
  final StopListeningUseCase _stopListening;
  final SetListeningModeUseCase _setListeningMode;
  final ObserveChatResponsesUseCase _observeResponses;
  final ObserveChatErrorsUseCase _observeErrors;
  final ObserveChatIncomingLevelUseCase _observeIncomingLevel;
  final ObserveChatOutgoingLevelUseCase _observeOutgoingLevel;
  final ObserveChatSpeakingUseCase _observeSpeaking;

  StreamSubscription<ChatResponse>? _responseSubscription;
  StreamSubscription<Failure>? _errorSubscription;
  StreamSubscription<bool>? _speakingSubscription;
  StreamSubscription<double>? _incomingLevelSubscription;
  StreamSubscription<double>? _outgoingLevelSubscription;
  Future<void>? _disconnecting;
  Completer<void>? _connectCompleter;

  bool _streamsAttached = false;
  bool _connectInFlight = false;
  bool _disposed = false;
  int _connectGeneration = 0;
  ChatConfig? _cachedConfig;

  double? _pendingIncomingLevel;
  double? _pendingOutgoingLevel;
  final Throttler _levelThrottle = Throttler(80);
  final Debouncer _levelDebouncer =
      Debouncer(const Duration(milliseconds: 80));
  Timer? _networkWarningTimer;
  DateTime? _ttsStartAt;
  String? _lastAgentText;
  static const Duration _networkWarningHold = Duration(seconds: 12);
  Future<void> initialize() async {
    await _attachStreams();
    await _connectWithConfig();
  }

  @override
  Future<void> connect() async {
    await _attachStreams();
    if (_disposed || isClosed) {
      return;
    }
    await _awaitDisconnecting();
    if (_disposed || isClosed) {
      return;
    }
    if (_connectInFlight) {
      final pendingConnect = _connectCompleter;
      if (pendingConnect != null) {
        try {
          await pendingConnect.future.timeout(
            const Duration(seconds: 5),
          );
        } catch (_) {}
      }
      _connectInFlight = false;
      _connectCompleter = null;
    }
    await _connectWithConfig();
  }

  @override
  Future<void> disconnect({bool userInitiated = true}) async {
    _connectGeneration += 1;
    if (!_disposed && !isClosed) {
      emit(
        state.copyWith(
          messages: const <ChatMessage>[],
          currentEmotion: 'neutral',
          incomingLevel: 0,
          outgoingLevel: 0,
          status: ChatConnectionStatus.idle,
          connectionError: userInitiated ? null : state.connectionError,
          networkWarning: userInitiated ? false : state.networkWarning,
          isSpeaking: false,
          lastTtsDurationMs: null,
          lastTtsText: null,
        ),
      );
    }
    _ttsStartAt = null;
    _lastAgentText = null;
    _disconnecting = _disconnect();
    await _awaitDisconnecting();
    _connectInFlight = false;
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _connectCompleter = null;
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final nextMessages = List<ChatMessage>.from(state.messages)
      ..add(
        ChatMessage(
          text: trimmed,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
    emit(
      state.copyWith(
        messages: List<ChatMessage>.unmodifiable(nextMessages),
        isSending: true,
      ),
    );
    _logMessage('[User] $trimmed');

    try {
      final result = await _sendMessage(trimmed);
      if (!result.isSuccess) {
        emit(state.copyWith(connectionError: result.failure?.message));
      }
    } finally {
      emit(state.copyWith(isSending: false));
    }
  }

  Future<void> setListeningMode(ListeningMode mode) async {
    await _setListeningMode(mode);
  }

  Future<void> stopListening() async {
    await _stopListening();
  }

  Future<void> _attachStreams() async {
    if (_streamsAttached) {
      return;
    }
    await _responseSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _speakingSubscription?.cancel();
    await _incomingLevelSubscription?.cancel();
    await _outgoingLevelSubscription?.cancel();

    _responseSubscription = _observeResponses().listen(_handleResponse);
    _errorSubscription = _observeErrors().listen(_handleError);
    _speakingSubscription = _observeSpeaking().listen(_handleSpeakingChanged);
    _incomingLevelSubscription =
        _observeIncomingLevel().listen(_updateIncomingLevel);
    _outgoingLevelSubscription =
        _observeOutgoingLevel().listen(_updateOutgoingLevel);
    _streamsAttached = true;
  }

  void _handleResponse(ChatResponse response) {
    final emotion = response.emotion?.trim();
    if (emotion != null &&
        emotion.isNotEmpty &&
        emotion != state.currentEmotion) {
      emit(state.copyWith(currentEmotion: emotion));
    }
    if (response.text.trim().isEmpty) {
      return;
    }
    final nextMessages = List<ChatMessage>.from(state.messages)
      ..add(
        ChatMessage(
          text: response.text,
          isUser: response.isUser,
          timestamp: DateTime.now(),
        ),
      );
    if (!response.isUser) {
      _lastAgentText = response.text.trim();
    }
    _logMessage(response.isUser ? '>> ${response.text}' : '<< ${response.text}');
    emit(state.copyWith(messages: List<ChatMessage>.unmodifiable(nextMessages)));
  }

  void _handleError(Failure failure) {
    final isNetworkIssue = _isNetworkFailure(failure.message);
    emit(
      state.copyWith(
        messages: const <ChatMessage>[],
        currentEmotion: 'neutral',
        incomingLevel: 0,
        outgoingLevel: 0,
        isSpeaking: false,
        connectionError: failure.message,
        status: ChatConnectionStatus.error,
        networkWarning: isNetworkIssue,
        lastTtsDurationMs: null,
        lastTtsText: null,
      ),
    );
    _ttsStartAt = null;
    _lastAgentText = null;
    AppLogger.event(
      'ChatCubit',
      'connection_error',
      fields: <String, Object?>{
        'message': failure.message,
        'code': failure.code,
      },
    );
    final isSocketClosed = failure.message == 'Socket closed';
    if (state.isSpeaking) {
      emit(state.copyWith(isSpeaking: false));
    }
    if (isSocketClosed) {
      unawaited(disconnect(userInitiated: false));
      return;
    }
    unawaited(disconnect(userInitiated: false));
  }

  void _handleSpeakingChanged(bool speaking) {
    if (state.isSpeaking == speaking) {
      return;
    }
    if (speaking) {
      _ttsStartAt = DateTime.now();
      emit(state.copyWith(isSpeaking: true));
      return;
    }
    final startedAt = _ttsStartAt;
    _ttsStartAt = null;
    if (startedAt == null) {
      emit(state.copyWith(isSpeaking: false));
      return;
    }
    final durationMs =
        DateTime.now().difference(startedAt).inMilliseconds;
    emit(
      state.copyWith(
        isSpeaking: false,
        lastTtsDurationMs: durationMs,
        lastTtsText: _lastAgentText,
      ),
    );
  }

  void _updateIncomingLevel(double level) {
    _pendingIncomingLevel = level;
    _emitLevelsThrottled();
  }

  void _updateOutgoingLevel(double level) {
    _pendingOutgoingLevel = level;
    _emitLevelsThrottled();
  }

  void _emitLevelsThrottled() {
    if (_levelThrottle.shouldRun()) {
      _emitLevelSnapshot();
      return;
    }
    _levelDebouncer.run(_emitLevelSnapshot);
  }

  void _emitLevelSnapshot() {
    if (_disposed || isClosed) {
      return;
    }
    final pendingIncoming = _pendingIncomingLevel;
    final pendingOutgoing = _pendingOutgoingLevel;
    if (pendingIncoming == null && pendingOutgoing == null) {
      return;
    }
    final nextIncoming = pendingIncoming ?? state.incomingLevel;
    final nextOutgoing = pendingOutgoing ?? state.outgoingLevel;
    _pendingIncomingLevel = null;
    _pendingOutgoingLevel = null;
    emit(
      state.copyWith(
        incomingLevel: nextIncoming,
        outgoingLevel: nextOutgoing,
      ),
    );
  }

  Future<void> _connectWithConfig() async {
    if (_connectInFlight || _disposed || isClosed) {
      return;
    }
    final generation = _connectGeneration;
    _connectInFlight = true;
    _connectCompleter = Completer<void>();
    emit(
      state.copyWith(
        status: ChatConnectionStatus.connecting,
        connectionError: null,
      ),
    );
    try {
      var config = _cachedConfig;
      var usedCached = config != null;

      Result<ChatConfig>? configResult;
      if (config == null) {
        try {
          configResult = await _loadConfig()
              .timeout(const Duration(seconds: 3));
        } on TimeoutException {
          // Ignore; will handle via fallback error below.
        }
        if (_disposed || isClosed || generation != _connectGeneration) {
          return;
        }
        if (configResult != null &&
            configResult.isSuccess &&
            configResult.data != null) {
          config = configResult.data!;
          _cachedConfig = config;
          usedCached = false;
        } else {
          final message =
              configResult?.failure?.message ?? 'Không thể kết nối';
          emit(
            state.copyWith(
              connectionError: message,
              status: ChatConnectionStatus.error,
            ),
          );
          _logMessage('connect skipped: $message');
          return;
        }
      }

      final configValue = config;
      var result = await _connect(configValue)
          .timeout(const Duration(seconds: 8));
      if (!result.isSuccess && usedCached) {
        try {
          configResult = await _loadConfig()
              .timeout(const Duration(seconds: 3));
        } on TimeoutException {
          // Ignore; retry will fall back to cached state.
        }
        if (_disposed || isClosed || generation != _connectGeneration) {
          return;
        }
        if (configResult != null &&
            configResult.isSuccess &&
            configResult.data != null) {
          config = configResult.data!;
          _cachedConfig = config;
          result = await _connect(config)
              .timeout(const Duration(seconds: 8));
        }
      }
      if (_disposed || isClosed || generation != _connectGeneration) {
        return;
      }
      if (!result.isSuccess) {
        final message = result.failure?.message ?? 'Không thể kết nối';
        final isNetworkIssue = _isNetworkFailure(message);
        emit(
          state.copyWith(
            messages: const <ChatMessage>[],
            currentEmotion: 'neutral',
            incomingLevel: 0,
            outgoingLevel: 0,
            isSpeaking: false,
            connectionError: message,
            status: ChatConnectionStatus.error,
            networkWarning: isNetworkIssue,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          connectionError: null,
          status: ChatConnectionStatus.connected,
        ),
      );
      if (state.networkWarning) {
        _scheduleNetworkWarningClear();
      }
      await _startListening().timeout(const Duration(seconds: 4));
    } on TimeoutException {
      if (_disposed || isClosed || generation != _connectGeneration) {
        return;
      }
      emit(
        state.copyWith(
          connectionError: 'Kết nối quá lâu, vui lòng thử lại.',
          status: ChatConnectionStatus.error,
        ),
      );
    } finally {
      _connectInFlight = false;
      _connectCompleter?.complete();
      _connectCompleter = null;
    }
  }

  Future<void> _awaitDisconnecting() async {
    final pending = _disconnecting;
    if (pending == null) {
      return;
    }
    try {
      await pending.timeout(const Duration(seconds: 1));
    } catch (_) {
      // Ignore disconnect errors/timeouts so reconnect can continue.
    } finally {
      _disconnecting = null;
    }
  }

  void _logMessage(String message) {
    AppLogger.log('ChatCubit', message);
  }

  void _scheduleNetworkWarningClear() {
    _networkWarningTimer?.cancel();
    _networkWarningTimer = Timer(_networkWarningHold, () {
      if (_disposed || isClosed) {
        return;
      }
      if (state.status == ChatConnectionStatus.connected &&
          state.networkWarning) {
        emit(state.copyWith(networkWarning: false));
      }
    });
  }

  bool _isNetworkFailure(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('thiếu thông tin') ||
        lower.contains('chưa có cấu hình')) {
      return false;
    }
    const networkHints = <String>[
      'socket closed',
      'server timeout',
      'server not found',
      'server not connected',
      'server error',
      'connection lost',
      'kết nối quá lâu',
      'không thể kết nối websocket',
      'không thể kết nối mqtt',
      'không thể kết nối',
    ];
    return networkHints.any(lower.contains);
  }

  @override
  Future<void> close() async {
    _disposed = true;
    _levelDebouncer.cancel();
    _networkWarningTimer?.cancel();
    await _responseSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _speakingSubscription?.cancel();
    await _incomingLevelSubscription?.cancel();
    await _outgoingLevelSubscription?.cancel();
    await _disconnect();
    return super.close();
  }
}
