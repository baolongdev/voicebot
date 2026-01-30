import 'dart:ffi';
import 'dart:io';

import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

Future<dynamic> loadOpusLibrary() async {
  if (Platform.isLinux) {
    try {
      return DynamicLibrary.open('libopus.so.0');
    } catch (_) {
      return DynamicLibrary.open('libopus.so');
    }
  }
  return opus_flutter.load();
}
