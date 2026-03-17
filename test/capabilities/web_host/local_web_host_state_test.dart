import 'package:flutter_test/flutter_test.dart';
import 'package:voicebot/capabilities/web_host/local_web_host_service.dart';

void main() {
  group('LocalWebHostState', () {
    test('running state exposes stable loopback and external URLs', () {
      const state = LocalWebHostState.running(ip: '192.168.1.25', port: 8080);

      expect(state.url, 'http://127.0.0.1:8080');
      expect(state.loopbackUrl, 'http://127.0.0.1:8080');
      expect(state.loopbackUri, Uri.parse('http://127.0.0.1:8080/'));
      expect(state.externalUrl, 'http://192.168.1.25:8080');
    });

    test('stopped state exposes no URLs', () {
      const state = LocalWebHostState.stopped();

      expect(state.url, isNull);
      expect(state.loopbackUrl, isNull);
      expect(state.loopbackUri, isNull);
      expect(state.externalUrl, isNull);
    });
  });
}
