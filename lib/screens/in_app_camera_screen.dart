import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';

/// Full-screen camera preview that stays inside the app.
/// Pops with JPEG [Uint8List] bytes, or `null` if cancelled.
class InAppCameraScreen extends StatefulWidget {
  const InAppCameraScreen({super.key});

  @override
  State<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends State<InAppCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
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
      _initCamera(_cameraIndex);
    }
  }

  Future<void> _open() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _initializing = false;
        _error = status.isPermanentlyDenied
            ? 'Camera permission is blocked. Enable it in Settings.'
            : 'Camera permission is needed to take a photo.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _error = 'No camera found on this device.';
        });
        return;
      }
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      await _initCamera(back >= 0 ? back : 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Could not open the camera. Try again.';
      });
    }
  }

  Future<void> _initCamera(int index) async {
    if (_cameras.isEmpty) return;
    setState(() {
      _initializing = true;
      _error = null;
      _cameraIndex = index.clamp(0, _cameras.length - 1);
    });

    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final next = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _initializing = false;
      });
    } catch (_) {
      await next.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Could not start the camera preview.';
      });
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _capturing) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _initCamera(next);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(Uint8List.fromList(bytes));
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not take that photo. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _preview()),
            Positioned(
              top: 8,
              left: 4,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const BackArrowGlyph(color: Colors.white, size: 24),
              ),
            ),
            if (_cameras.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Flip camera',
                  onPressed: _capturing ? null : _flip,
                  icon: const Icon(
                    Icons.cameraswitch_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(
                child: GestureDetector(
                  onTap: _capturing ? null : _capture,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _capturing
                          ? AppColors.terracotta.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: _capturing ? 28 : 58,
                        height: _capturing ? 28 : 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _capturing
                              ? AppColors.terracotta
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (_error != null) {
      return _MessagePane(
        message: _error!,
        actionLabel: _error!.contains('Settings') ? 'Open settings' : 'Retry',
        onAction: () async {
          if (_error!.contains('Settings')) {
            await openAppSettings();
          } else {
            await _open();
          }
        },
      );
    }

    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.white70,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
