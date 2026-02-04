import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeCameraOverlay extends StatefulWidget {
  const HomeCameraOverlay({
    super.key,
    required this.areaSize,
    required this.enabled,
    required this.onEnabledChanged,
    required this.aspectRatio,
  });

  final Size areaSize;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final double aspectRatio;

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
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width:
                          _controller!.value.previewSize?.height ??
                          _boxSize.width,
                      height:
                          _controller!.value.previewSize?.width ??
                          _boxSize.height,
                      child: CameraPreview(_controller!),
                    ),
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
      if (!mounted) {
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
  }

  void _disposeCamera() {
    _controller?.dispose();
    _controller = null;
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
}
