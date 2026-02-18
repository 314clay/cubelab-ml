import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';

/// Camera preview widget that manages the CameraController lifecycle.
/// Use a GlobalKey<CameraPreviewWidgetState> to trigger capture from parent.
class CameraPreviewWidget extends StatefulWidget {
  final void Function(Uint8List imageBytes) onCapture;

  const CameraPreviewWidget({super.key, required this.onCapture});

  @override
  CameraPreviewWidgetState createState() => CameraPreviewWidgetState();
}

class CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  /// Whether the camera is ready to capture.
  bool get isReady => _isInitialized && !_isCapturing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras found');
        return;
      }

      // Prefer the back camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera error: $e');
      }
    }
  }

  /// Trigger a photo capture. Called by parent via GlobalKey.
  Future<void> capture() async {
    final controller = _controller;
    if (controller == null || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      widget.onCapture(Uint8List.fromList(bytes));
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Capture failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildError();
    }

    if (!_isInitialized || _controller == null) {
      return _buildLoading();
    }

    return _buildPreview();
  }

  Widget _buildPreview() {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.previewSize?.height ?? 1,
            height: _controller!.value.previewSize?.width ?? 1,
            child: CameraPreview(_controller!),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          SizedBox(height: AppSpacing.md),
          Text('Starting camera...', style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage ?? 'Camera unavailable',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: _initCamera,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
