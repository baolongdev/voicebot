import 'dart:async';
import 'dart:typed_data';

import '../../core/system/ota/model/ota_result.dart';
import '../protocol/protocol.dart';
import '../protocol/mqtt_protocol.dart';
import 'transport_client.dart';

class MqttTransportClient implements TransportClient {
  MqttTransportClient({
    required this.mqttConfig,
  });

  final MqttConfig mqttConfig;

  final StreamController<Map<String, dynamic>> _jsonController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  MqttProtocol? _protocol;
  StreamSubscription<Map<String, dynamic>>? _jsonSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<String>? _errorSubscription;
  bool _isConnected = false;

  @override
  Stream<Map<String, dynamic>> get jsonStream => _jsonController.stream;

  @override
  Stream<Uint8List> get audioStream => _audioController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  int get serverSampleRate => -1;

  @override
  String get sessionId => _protocol?.sessionId ?? '';

  @override
  Future<bool> connect() async {
    if (_isConnected) {
      return true;
    }
    _protocol = MqttProtocol(mqttConfig: mqttConfig);
    final opened = await _protocol!.openAudioChannel();
    if (!opened) {
      _errorController.add('Không thể kết nối MQTT');
      return false;
    }
    _isConnected = true;
    _jsonSubscription = _protocol!.incomingJsonStream.stream.listen(
      (json) => _jsonController.add(json),
      onError: (_) => _errorController.add('Lỗi nhận dữ liệu'),
    );
    _audioSubscription = _protocol!.incomingAudioStream.stream.listen(
      (data) => _audioController.add(data),
      onError: (_) => _errorController.add('Lỗi nhận âm thanh'),
    );
    _errorSubscription = _protocol!.networkErrorStream.stream.listen(
      (error) => _errorController.add(error),
    );
    return true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    await _jsonSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _errorSubscription?.cancel();
    _jsonSubscription = null;
    _audioSubscription = null;
    _errorSubscription = null;
    _protocol?.dispose();
    _protocol = null;
  }

  @override
  Future<void> sendText(String text) async {
    await _protocol?.sendText(text);
  }

  @override
  Future<void> sendAudio(Uint8List data) async {
    await _protocol?.sendAudio(data);
  }

  @override
  Future<void> startListening(ListeningMode mode) async {
    await _protocol?.sendStartListening(mode);
  }

  @override
  Future<void> stopListening() async {
    await _protocol?.sendStopListening();
  }
}
