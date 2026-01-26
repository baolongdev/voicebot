import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

// Ported from Android Kotlin: UdpClient.kt
class UdpClient {
  UdpClient(this._server, this._port) {
    _start();
  }

  final String _server;
  final int _port;
  RawDatagramSocket? _socket;
  InternetAddress? _address;
  bool _isRunning = false;
  void Function(Uint8List data)? _onMessage;

  Future<void> _start() async {
    try {
      _address = InternetAddress(_server);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.readEventsEnabled = true;
      _socket!.writeEventsEnabled = true;
      _isRunning = true;
      _socket!.listen((event) {
        if (!_isRunning) {
          return;
        }
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram == null) {
            return;
          }
          _onMessage?.call(Uint8List.fromList(datagram.data));
        }
      });
    } catch (_) {
      close();
    }
  }

  void setOnMessage(void Function(Uint8List data) callback) {
    _onMessage = callback;
  }

  void send(Uint8List data) {
    if (!_isRunning || _socket == null || _address == null) {
      return;
    }
    _socket!.send(data, _address!, _port);
  }

  void close() {
    _isRunning = false;
    _socket?.close();
    _socket = null;
  }
}
