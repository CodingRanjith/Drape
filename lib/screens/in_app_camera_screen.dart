import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../widgets/scanner_shape_guide.dart';

/// GPay-style in-app scanner — live preview stays inside the app.
/// Never launches the system camera app.
/// Pops with JPEG [Uint8List] bytes, or `null` if cancelled.
class InAppCameraScreen extends StatefulWidget {
  const InAppCameraScreen({
    super.key,
    this.shape = ScannerShape.generic,
    this.guideLabel,
  });

  final ScannerShape shape;
  final String? guideLabel;

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
            : 'Camera permission is needed to scan.';
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
        _error = 'Could not open the scanner. Try again on a phone.';
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
        _error = 'Could not start the scanner preview.';
      });
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _capturing) return;
    await _initCamera((_cameraIndex + 1) % _cameras.length);
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
        const SnackBar(content: Text('Could not capture. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _error == null &&
        !_initializing &&
        _controller?.value.isInitialized == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _preview()),
          if (ready)
            Positioned.fill(
              child: ScannerShapeOverlay(
                shape: widget.shape,
                label: widget.guideLabel,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_cameras.length > 1)
                    IconButton(
                      tooltip: 'Flip camera',
                      onPressed: _capturing ? null : _flip,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.cameraswitch_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.guideLabel == null
                            ? 'Hold steady inside the frame'
                            : 'Fit ${widget.guideLabel} in the frame',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _capturing ? null : _capture,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: _capturing ? 30 : 62,
                              height: _capturing ? 30 : 62,
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
                    ],
                  ),
                ),
              ),
            ),
        ],
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

    // Full-bleed preview like GPay / UPI scanners.
    final size = MediaQuery.sizeOf(context);
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final previewAspect = previewSize.height / previewSize.width;
    var scale = size.aspectRatio * previewAspect;
    if (scale < 1) scale = 1 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: AspectRatio(
            aspectRatio: previewAspect,
            child: CameraPreview(controller),
          ),
        ),
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
              Icons.document_scanner_outlined,
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
