import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
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

  Future<List<Face>> detectFromCameraImage(
    CameraImage image, {
    FaceDetectionMode mode = FaceDetectionMode.fast,
  }) async {
    if (_detector == null) {
      return const <Face>[];
    }
    final bytes = _convertToJpeg(image);
    return _detector!.detectFaces(bytes, mode: mode);
  }

  Future<void> dispose() async {
    final detector = _detector;
    _detector = null;
    if (detector != null) {
      await detector.dispose();
    }
  }

  Uint8List _convertToJpeg(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final img = imglib.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      final uvRow = uvRowStride * (y >> 1);
      final yRow = yRowStride * y;
      for (var x = 0; x < width; x++) {
        final uvIndex = uvRow + (x >> 1) * uvPixelStride;
        final yIndex = yRow + x;

        final yValue = yBytes[yIndex];
        final uValue = uBytes[uvIndex];
        final vValue = vBytes[uvIndex];

        final r = (yValue + 1.403 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yValue + 1.770 * (uValue - 128))
            .clamp(0, 255)
            .toInt();

        img.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(imglib.encodeJpg(img, quality: 85));
  }
}
