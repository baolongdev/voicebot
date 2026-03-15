import 'dart:async';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as imglib;

class FaceDetectionEngine {
  FaceDetectorIsolate? _detector;
  bool _initializing = false;

  Future<void> initialize({
    FaceDetectionModel model = FaceDetectionModel.frontCamera,
  }) async {
    if (_detector != null || _initializing) {
      return;
    }
    _initializing = true;
    _detector = await FaceDetectorIsolate.spawn(model: model);
    _initializing = false;
  }

  Future<List<Face>> detectFromFrame(
    FaceDetectionFrame frame, {
    FaceDetectionMode mode = FaceDetectionMode.fast,
  }) async {
    if (_detector == null) {
      return const <Face>[];
    }
    final bytes = await compute(_convertFrameToJpeg, frame.toMessage());
    return _detector!.detectFaces(bytes, mode: mode);
  }

  Future<void> dispose() async {
    final detector = _detector;
    _detector = null;
    if (detector != null) {
      await detector.dispose();
    }
  }
}

class FaceDetectionFrame {
  const FaceDetectionFrame({
    required this.width,
    required this.height,
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  factory FaceDetectionFrame.fromCameraImage(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    return FaceDetectionFrame(
      width: image.width,
      height: image.height,
      yBytes: Uint8List.fromList(yPlane.bytes),
      uBytes: Uint8List.fromList(uPlane.bytes),
      vBytes: Uint8List.fromList(vPlane.bytes),
      yRowStride: yPlane.bytesPerRow,
      uvRowStride: uPlane.bytesPerRow,
      uvPixelStride: uPlane.bytesPerPixel ?? 1,
    );
  }

  final int width;
  final int height;
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  Map<String, Object> toMessage() {
    return <String, Object>{
      'width': width,
      'height': height,
      'yBytes': yBytes,
      'uBytes': uBytes,
      'vBytes': vBytes,
      'yRowStride': yRowStride,
      'uvRowStride': uvRowStride,
      'uvPixelStride': uvPixelStride,
    };
  }
}

@pragma('vm:entry-point')
Uint8List _convertFrameToJpeg(Map<String, Object> message) {
  final width = message['width']! as int;
  final height = message['height']! as int;
  final yBytes = message['yBytes']! as Uint8List;
  final uBytes = message['uBytes']! as Uint8List;
  final vBytes = message['vBytes']! as Uint8List;
  final yRowStride = message['yRowStride']! as int;
  final uvRowStride = message['uvRowStride']! as int;
  final uvPixelStride = message['uvPixelStride']! as int;

  final img = imglib.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final uvRow = uvRowStride * (y >> 1);
    final yRow = yRowStride * y;
    for (var x = 0; x < width; x++) {
      final uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final yIndex = yRow + x;

      final yValue = yBytes[yIndex];
      final uValue = uBytes[uvIndex];
      final vValue = vBytes[uvIndex];

      final r = (yValue + 1.403 * (vValue - 128)).clamp(0, 255).toInt();
      final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128))
          .clamp(0, 255)
          .toInt();
      final b = (yValue + 1.770 * (uValue - 128)).clamp(0, 255).toInt();
      img.setPixelRgb(x, y, r, g, b);
    }
  }
  // Lower quality helps reduce encode cost and memory churn in live analysis.
  return Uint8List.fromList(imglib.encodeJpg(img, quality: 72));
}
