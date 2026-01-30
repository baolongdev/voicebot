import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_response.dart';
import '../usecases/connect_chat_usecase.dart';
import '../usecases/disconnect_chat_usecase.dart';
import '../usecases/load_chat_config_usecase.dart';
import '../usecases/observe_chat_errors_usecase.dart';
import '../usecases/observe_chat_responses_usecase.dart';
import '../usecases/observe_chat_speaking_usecase.dart';
import '../usecases/send_chat_message_usecase.dart';
import '../usecases/start_listening_usecase.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required LoadChatConfigUseCase loadConfig,
    required ConnectChatUseCase connect,
    required DisconnectChatUseCase disconnect,
    required SendChatMessageUseCase sendMessage,
    required StartListeningUseCase startListening,
    required ObserveChatResponsesUseCase observeResponses,
    required ObserveChatErrorsUseCase observeErrors,
    required ObserveChatSpeakingUseCase observeSpeaking,
  })  : _loadConfig = loadConfig,
        _connect = connect,
        _disconnect = disconnect,
        _sendMessage = sendMessage,
        _startListening = startListening,
        _observeResponses = observeResponses,
        _observeErrors = observeErrors,
        _observeSpeaking = observeSpeaking;

  final LoadChatConfigUseCase _loadConfig;
  final ConnectChatUseCase _connect;
  final DisconnectChatUseCase _disconnect;
  final SendChatMessageUseCase _sendMessage;
  final StartListeningUseCase _startListening;
  final ObserveChatResponsesUseCase _observeResponses;
  final ObserveChatErrorsUseCase _observeErrors;
  final ObserveChatSpeakingUseCase _observeSpeaking;

  final List<ChatMessage> _messages = <ChatMessage>[];
  bool _isSending = false;
  bool _isSpeaking = false;
  String? _connectionError;

  StreamSubscription<ChatResponse>? _responseSubscription;
  StreamSubscription<Failure>? _errorSubscription;
  StreamSubscription<bool>? _speakingSubscription;
  Timer? _retryTimer;
  bool _isListening = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  String? get connectionError => _connectionError;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _attachStreams();
    await _connectWithConfig();
  }

  Future<void> _attachStreams() async {
    await _responseSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _speakingSubscription?.cancel();

    _responseSubscription = _observeResponses().listen((response) {
      if (response.text.trim().isEmpty) {
        return;
      }
      _messages.add(
        ChatMessage(
          text: response.text,
          isUser: response.isUser,
          timestamp: DateTime.now(),
        ),
      );
      _logMessage(response.isUser ? '>> ${response.text}' : '<< ${response.text}');
      notifyListeners();
    });

    _errorSubscription = _observeErrors().listen((failure) {
      _connectionError = failure.message;
      _logMessage('connection error: ${failure.message}');
      _isListening = false;
      _scheduleRetry();
      notifyListeners();
    });

    _speakingSubscription = _observeSpeaking().listen(_handleSpeakingChanged);
  }

  Future<void> _connectWithConfig() async {
    final configResult = await _loadConfig();
    if (!configResult.isSuccess || configResult.data == null) {
      _connectionError = configResult.failure?.message ?? 'Không thể kết nối';
      _logMessage('connect skipped: ${_connectionError ?? 'missing config'}');
      _scheduleRetry();
      notifyListeners();
      return;
    }

    _retryTimer?.cancel();
    final result = await _connect(configResult.data!);
    if (!result.isSuccess) {
      _connectionError = result.failure?.message ?? 'Không thể kết nối';
      _scheduleRetry();
      notifyListeners();
      return;
    }
    _connectionError = null;
    await _startListeningIfNeeded();
  }

  Future<void> _handleSpeakingChanged(bool speaking) async {
    _isSpeaking = speaking;
    notifyListeners();
  }

  Future<void> _startListeningIfNeeded() async {
    if (_isListening) {
      return;
    }
    await _startListening();
    _isListening = true;
  }


  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _messages.add(
      ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    _logMessage('[User] $trimmed');
    _isSending = true;
    notifyListeners();

    try {
      final result = await _sendMessage(trimmed);
      if (!result.isSuccess && result.failure != null) {
        _connectionError = result.failure?.message;
      }
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _errorSubscription?.cancel();
    _isListening = false;
    _retryTimer?.cancel();
    _disconnect();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryTimer != null) {
      return;
    }
    const retryDelay = Duration(seconds: 2);
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      _connectWithConfig();
    });
  }

  void _logMessage(String message) {
    AppLogger.log('ChatViewModel', message);
  }
}
