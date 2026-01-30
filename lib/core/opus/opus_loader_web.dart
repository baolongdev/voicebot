import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

Future<dynamic> loadOpusLibrary() async {
  return opus_flutter.load();
}
