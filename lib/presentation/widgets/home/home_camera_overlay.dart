import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../capabilities/vision/face_detection_engine.dart';

class HomeCameraOverlay extends StatefulWidget {
  const HomeCameraOverlay({
    super.key,
    required this.areaSize,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onFacePresenceChanged,
    required this.detectFacesEnabled,
    required this.aspectRatio,
    required this.faceLandmarksEnabled,
    required this.faceMeshEnabled,
    required this.eyeTrackingEnabled,
  });

  final Size areaSize;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onFacePresenceChanged;
  final bool detectFacesEnabled;
  final double aspectRatio;
  final bool faceLandmarksEnabled;
  final bool faceMeshEnabled;
  final bool eyeTrackingEnabled;

  @override
  State<HomeCameraOverlay> createState() => _HomeCameraOverlayState();
}

class _HomeCameraOverlayState extends State<HomeCameraOverlay> {
  static const Size _defaultBoxSize = Size(200, 130);
  static const double _edgePadding = 12;
  bool _initialized = false;
  Offset _offset = const Offset(_edgePadding, _edgePadding);
  bool _isDragging = false;
  bool _cameraEnabled = false;
  bool _cameraInitializing = false;
  CameraController? _controller;
  Size _boxSize = _defaultBoxSize;
  final FaceDetectionEngine _faceEngine = FaceDetectionEngine();
  bool _faceReady = false;
  bool _faceProcessing = false;
  int _lastDetectMs = 0;
  Size? _lastImageSize;
  Size? _previewSize;
  List<Face> _faces = const [];
  int _rotationDegrees = 0;
  bool _hadFace = false;

  @override
  void didUpdateWidget(covariant HomeCameraOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized && widget.areaSize.width > 0) {
      _initialized = true;
      final next = Offset(
        widget.areaSize.width - _boxSize.width - _edgePadding,
        _edgePadding,
      );
      _offset = _clampOffset(next);
      return;
    }
    if (oldWidget.areaSize != widget.areaSize) {
      _offset = _clampOffset(_offset);
    }
    if (oldWidget.detectFacesEnabled != widget.detectFacesEnabled &&
        !widget.detectFacesEnabled) {
      _clearFaceState(clearPreview: false);
    }
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _startCamera();
      } else {
        _stopCamera();
      }
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    _faceEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.areaSize.width <= 0 || widget.areaSize.height <= 0) {
      return const SizedBox.shrink();
    }
    if (widget.enabled && !_cameraEnabled && !_cameraInitializing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startCamera();
        }
      });
    }
    final nextBoxSize = _resolveBoxSize(widget.areaSize, widget.aspectRatio);
    if (nextBoxSize != _boxSize) {
      _boxSize = nextBoxSize;
      _offset = _clampOffset(_offset);
    }
    final facesForOverlay =
        widget.detectFacesEnabled ? _faces : const <Face>[];
    return AnimatedPositioned(
      left: _offset.dx,
      top: _offset.dy,
      duration: _isDragging
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _offset = _clampOffset(_offset + details.delta);
          });
        },
        onPanEnd: (_) => _snapToEdge(),
        onPanCancel: _snapToEdge,
        child: Container(
          width: _boxSize.width,
          height: _boxSize.height,
          decoration: BoxDecoration(
            color: context.theme.colors.muted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.theme.colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_cameraEnabled && _controller?.value.isInitialized == true)
                  _CameraPreviewLayer(
                    controller: _controller!,
                    faces: facesForOverlay,
                    imageSize: _lastImageSize,
                    previewSize: _previewSize,
                    rotationDegrees: _rotationDegrees,
                    color: context.theme.colors.primary,
                  )
                else
                  Container(
                    color: context.theme.colors.background,
                  ),
                if (!_cameraEnabled)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.theme.colors.muted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.theme.colors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_outlined,
                            size: 32,
                            color: context.theme.colors.mutedForeground,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera',
                            style: context.theme.typography.sm.copyWith(
                              color: context.theme.colors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_cameraInitializing)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Offset _clampOffset(Offset offset) {
    final maxX = math.max(
      _edgePadding,
      widget.areaSize.width - _boxSize.width - _edgePadding,
    );
    final maxY = math.max(
      _edgePadding,
      widget.areaSize.height - _boxSize.height - _edgePadding,
    );
    return Offset(
      offset.dx.clamp(_edgePadding, maxX),
      offset.dy.clamp(_edgePadding, maxY),
    );
  }

  void _snapToEdge() {
    final maxX = math.max(
      _edgePadding,
      widget.areaSize.width - _boxSize.width - _edgePadding,
    );
    final maxY = math.max(
      _edgePadding,
      widget.areaSize.height - _boxSize.height - _edgePadding,
    );
    final left = (_offset.dx - _edgePadding).abs();
    final right = (maxX - _offset.dx).abs();
    final top = (_offset.dy - _edgePadding).abs();
    final bottom = (maxY - _offset.dy).abs();

    var target = _offset;
    final minDist = math.min(math.min(left, right), math.min(top, bottom));
    if (minDist == left) {
      target = Offset(_edgePadding, _offset.dy);
    } else if (minDist == right) {
      target = Offset(maxX, _offset.dy);
    } else if (minDist == top) {
      target = Offset(_offset.dx, _edgePadding);
    } else {
      target = Offset(_offset.dx, maxY);
    }
    setState(() {
      _isDragging = false;
      _offset = _clampOffset(target);
    });
  }

  Future<void> _startCamera() async {
    setState(() {
      _cameraInitializing = true;
    });
    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }
    if (!status.isGranted) {
      setState(() {
        _cameraInitializing = false;
      });
      widget.onEnabledChanged(false);
      showFToast(
        context: context,
        alignment: FToastAlignment.topRight,
        duration: const Duration(seconds: 1),
        icon: const Icon(FIcons.cameraOff),
        title: const Text('Cần quyền camera'),
        description: const Text('Hãy cấp quyền camera để bật xem trước.'),
      );
      return;
    }
    final cameras = await availableCameras();
    if (!mounted) {
      return;
    }
    CameraDescription? frontCamera;
    for (final cam in cameras) {
      if (cam.lensDirection == CameraLensDirection.front) {
        frontCamera = cam;
        break;
      }
    }
    frontCamera ??= cameras.isNotEmpty ? cameras.first : null;
    if (frontCamera == null) {
      setState(() {
        _cameraInitializing = false;
      });
      widget.onEnabledChanged(false);
      showFToast(
        context: context,
        alignment: FToastAlignment.topRight,
        duration: const Duration(seconds: 1),
        icon: const Icon(FIcons.cameraOff),
        title: const Text('Không tìm thấy camera'),
        description: const Text('Thiết bị không có camera trước.'),
      );
      return;
    }
    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      _rotationDegrees = _resolveRotationDegrees(controller);
      _previewSize = controller.value.previewSize;
      await _initializeFaceDetector();
      await controller.startImageStream(_processCameraImage);
      if (!mounted) {
        await controller.stopImageStream();
        await controller.dispose();
        return;
      }
      setState(() {
        _controller?.dispose();
        _controller = controller;
        _cameraEnabled = true;
        _cameraInitializing = false;
      });
      widget.onEnabledChanged(true);
      showFToast(
        context: context,
        alignment: FToastAlignment.topRight,
        duration: const Duration(seconds: 1),
        icon: const Icon(FIcons.camera),
        title: const Text('Bật camera'),
        description: const Text('Nhấn lần nữa để tắt camera.'),
      );
    } catch (_) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraEnabled = false;
        _cameraInitializing = false;
      });
      widget.onEnabledChanged(false);
      showFToast(
        context: context,
        alignment: FToastAlignment.topRight,
        duration: const Duration(seconds: 1),
        icon: const Icon(FIcons.cameraOff),
        title: const Text('Không bật được camera'),
        description: const Text('Vui lòng thử lại.'),
      );
    }
  }

  void _stopCamera() {
    _disposeCamera();
    if (!mounted) {
      return;
    }
    setState(() {
      _cameraEnabled = false;
      _cameraInitializing = false;
    });
    _clearFaceState(clearPreview: true);
  }

  void _disposeCamera() {
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
    }
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializeFaceDetector() async {
    if (_faceReady) {
      return;
    }
    await _faceEngine.initialize(
      model: FaceDetectionModel.frontCamera,
    );
    _faceReady = true;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_cameraEnabled || !_faceReady || _faceProcessing) {
      return;
    }
    if (!widget.detectFacesEnabled) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDetectMs < 150) {
      return;
    }
    _lastDetectMs = now;
    _faceProcessing = true;
    try {
      final nextRotation = _controller == null
          ? _rotationDegrees
          : _resolveRotationDegrees(_controller!);
      if (nextRotation != _rotationDegrees && mounted) {
        setState(() {
          _rotationDegrees = nextRotation;
        });
      }
      final faces = await _faceEngine.detectFromCameraImage(
        image,
        mode: _resolveDetectionMode(),
      );
      if (!mounted) {
        return;
      }
      final hasFace = faces.isNotEmpty;
      if (hasFace != _hadFace) {
        _hadFace = hasFace;
        widget.onFacePresenceChanged(hasFace);
      }
      if (!hasFace) {
        _faces = const [];
      }
      setState(() {
        if (hasFace) {
          _faces = faces;
        }
        _lastImageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      });
    } catch (_) {
      // Ignore frame failures.
    } finally {
      _faceProcessing = false;
    }
  }

  Size _resolveBoxSize(Size areaSize, double aspectRatio) {
    final safeAspect = aspectRatio <= 0 ? 1.0 : aspectRatio;
    final maxWidth = math.max(0.0, areaSize.width - _edgePadding * 2);
    final maxHeight = math.max(0.0, areaSize.height - _edgePadding * 2);
    var width = math.min(_defaultBoxSize.width, maxWidth);
    var height = width / safeAspect;
    if (height > maxHeight && maxHeight > 0) {
      height = maxHeight;
      width = height * safeAspect;
    }
    width = width.clamp(120, maxWidth);
    height = width / safeAspect;
    return Size(width.toDouble(), height.toDouble());
  }

  FaceDetectionMode _resolveDetectionMode() {
    if (widget.eyeTrackingEnabled) {
      return FaceDetectionMode.full;
    }
    if (widget.faceMeshEnabled) {
      return FaceDetectionMode.standard;
    }
    if (widget.faceLandmarksEnabled) {
      return FaceDetectionMode.fast;
    }
    return FaceDetectionMode.fast;
  }

  void _clearFaceState({required bool clearPreview}) {
    if (_hadFace) {
      _hadFace = false;
      widget.onFacePresenceChanged(false);
    }
    if (!mounted) {
      _faces = const [];
      _lastImageSize = null;
      if (clearPreview) {
        _previewSize = null;
      }
      return;
    }
    setState(() {
      _faces = const [];
      _lastImageSize = null;
      if (clearPreview) {
        _previewSize = null;
      }
    });
  }

  int _resolveRotationDegrees(CameraController controller) {
    final sensorOrientation = controller.description.sensorOrientation;
    final deviceOrientation = controller.value.deviceOrientation;
    final deviceRotation = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    if (controller.description.lensDirection == CameraLensDirection.front) {
      final rotation = (sensorOrientation + deviceRotation) % 360;
      return (360 - rotation) % 360;
    }
    return (sensorOrientation - deviceRotation + 360) % 360;
  }
}

class _CameraPreviewLayer extends StatelessWidget {
  const _CameraPreviewLayer({
    required this.controller,
    required this.faces,
    required this.imageSize,
    required this.previewSize,
    required this.rotationDegrees,
    required this.color,
  });

  final CameraController controller;
  final List<Face> faces;
  final Size? imageSize;
  final Size? previewSize;
  final int rotationDegrees;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final preview = previewSize ??
        controller.value.previewSize ??
        const Size(1, 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest;
        final isQuarterTurn =
            rotationDegrees == 90 || rotationDegrees == 270;
        final effectivePreview = isQuarterTurn
            ? Size(preview.height, preview.width)
            : preview;
        final previewRatio = effectivePreview.width / effectivePreview.height;
        final boxRatio = boxSize.width / boxSize.height;
        double childWidth;
        double childHeight;
        if (previewRatio > boxRatio) {
          childHeight = boxSize.height;
          childWidth = childHeight * previewRatio;
        } else {
          childWidth = boxSize.width;
          childHeight = childWidth / previewRatio;
        }
        final displaySize = Size(childWidth, childHeight);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            maxWidth: childWidth,
            maxHeight: childHeight,
            child: SizedBox(
              width: childWidth,
              height: childHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  if (faces.isNotEmpty && imageSize != null)
                    CustomPaint(
                      painter: _FaceOverlayPainter(
                        faces: faces,
                        imageSize: imageSize!,
                        previewSize: preview,
                        displaySize: displaySize,
                        rotationDegrees: rotationDegrees,
                        mirror:
                            controller.description.lensDirection ==
                            CameraLensDirection.front,
                        color: color,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FaceOverlayPainter extends CustomPainter {
  _FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.previewSize,
    required this.displaySize,
    required this.rotationDegrees,
    required this.mirror,
    required this.color,
  });

  final List<Face> faces;
  final Size imageSize;
  final Size? previewSize;
  final Size displaySize;
  final int rotationDegrees;
  final bool mirror;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final face in faces) {
      final box = face.boundingBox;
      final rect = _mapBoundingBox(box);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );
    }
  }

  Rect _mapBoundingBox(BoundingBox box) {
    final corners = <Offset>[
      _toOffset(box.topLeft),
      _toOffset(box.topRight),
      _toOffset(box.bottomRight),
      _toOffset(box.bottomLeft),
    ];

    final isQuarterTurn = rotationDegrees == 90 || rotationDegrees == 270;
    final sourceSize = isQuarterTurn
        ? Size(imageSize.height, imageSize.width)
        : imageSize;
    final previewSource = previewSize == null
        ? sourceSize
        : (isQuarterTurn
            ? Size(previewSize!.height, previewSize!.width)
            : previewSize!);

    final transformed = corners.map((point) {
      var result = _rotatePoint(point);
      if (mirror) {
        result = Offset(sourceSize.width - result.dx, result.dy);
      }
      return result;
    }).toList();

    var rect = _boundsForPoints(transformed);
    if (previewSource != sourceSize &&
        sourceSize.width > 0 &&
        sourceSize.height > 0) {
      final scaleX = previewSource.width / sourceSize.width;
      final scaleY = previewSource.height / sourceSize.height;
      rect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );
    }

    if (previewSource.width > 0 && previewSource.height > 0) {
      final scaleX = displaySize.width / previewSource.width;
      final scaleY = displaySize.height / previewSource.height;
      rect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );
    }

    return Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);
  }

  Offset _toOffset(Point point) => Offset(point.x.toDouble(), point.y.toDouble());

  Offset _rotatePoint(Offset point) {
    switch (rotationDegrees) {
      case 90:
        return Offset(point.dy, imageSize.width - point.dx);
      case 180:
        return Offset(
          imageSize.width - point.dx,
          imageSize.height - point.dy,
        );
      case 270:
        return Offset(imageSize.height - point.dy, point.dx);
      default:
        return point;
    }
  }

  Rect _boundsForPoints(List<Offset> points) {
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final point in points.skip(1)) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.previewSize != previewSize ||
        oldDelegate.displaySize != displaySize ||
        oldDelegate.rotationDegrees != rotationDegrees ||
        oldDelegate.mirror != mirror ||
        oldDelegate.color != color;
  }
}
