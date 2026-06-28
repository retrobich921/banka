import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';

/// Экран съёмки фото банки сразу в квадрате (1:1).
///
/// Показывает живое превью в квадратной рамке (как будет выглядеть кадр),
/// по спуску делает снимок, центр-кропит его в 1:1, сжимает в JPEG и
/// возвращает `File` через `Navigator.pop`. Возврат `null` — пользователь
/// закрыл экран без снимка.
class SquareCameraPage extends StatefulWidget {
  const SquareCameraPage({super.key});

  @override
  State<SquareCameraPage> createState() => _SquareCameraPageState();
}

class _SquareCameraPageState extends State<SquareCameraPage>
    with WidgetsBindingObserver {
  static const int _maxDimension = 1600;
  static const int _jpegQuality = 85;

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  bool _initializing = true;
  bool _permissionDenied = false;
  bool _capturing = false;
  bool _switching = false;
  bool _flipping = false;
  FlashMode _flashMode = FlashMode.off;
  bool _screenFlash = false;
  String? _error;

  /// Точка тапа для индикатора фокуса (в координатах квадратного превью).
  Offset? _focusPoint;
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Тап по превью — навести фокус и экспозицию на точку.
  Future<void> _focusOnTap(Offset localPosition, double side) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final dx = (localPosition.dx / side).clamp(0.0, 1.0);
    final dy = (localPosition.dy / side).clamp(0.0, 1.0);
    setState(() => _focusPoint = localPosition);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusPoint = null);
    });
    try {
      await controller.setFocusPoint(Offset(dx, dy));
      await controller.setExposurePoint(Offset(dx, dy));
    } catch (_) {
      // Некоторые камеры не поддерживают точечный фокус — молча игнорируем.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initController(_cameraIndex);
    }
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _initializing = false;
      });
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Камера не найдена';
          _initializing = false;
        });
        return;
      }
      // Стартуем с тыловой камеры, если есть.
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _initController(_cameraIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть камеру: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _initController(int index) async {
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      // Восстанавливаем выбранный режим вспышки (фронталка может не уметь).
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть камеру: $e';
        _initializing = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _error = null;
    });
  }

  Future<void> _flipCamera() async {
    final controller = _controller;
    if (_cameras.length < 2 ||
        _capturing ||
        _switching ||
        _flipping ||
        controller == null) {
      return;
    }
    _flipping = true;
    final next = (_cameraIndex + 1) % _cameras.length;
    try {
      // setDescription переключает камеру на том же контроллере/текстуре —
      // превью НЕ прячем под лоадер (иначе CameraPreview отцепится от
      // текстуры и мигнёт). Так переключение без вспышки экрана.
      await controller.setDescription(_cameras[next]);
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {}
      if (mounted) setState(() => _cameraIndex = next);
    } catch (_) {
      // Фолбэк: устройство не умеет setDescription — пересоздаём контроллер
      // (здесь лоадер уместен, текстуры всё равно нет).
      if (mounted) setState(() => _switching = true);
      await controller.dispose();
      _controller = null;
      _cameraIndex = next;
      await _initController(next);
      if (mounted) setState(() => _switching = false);
    } finally {
      _flipping = false;
    }
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flashMode) + 1) % order.length];
    setState(() => _flashMode = next);
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {
      // Камера без вспышки (напр. фронтальная) — игнорируем.
    }
  }

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.off => Icons.flash_off,
    FlashMode.auto => Icons.flash_auto,
    FlashMode.always => Icons.flash_on,
    FlashMode.torch => Icons.highlight,
  };

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing) {
      return;
    }
    // У фронтальной камеры нет аппаратной вспышки — подсвечиваем белым
    // экраном (screen flash), если вспышка включена/в авто.
    final isFront =
        _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
    final useScreenFlash = isFront && _flashMode != FlashMode.off;

    setState(() {
      _capturing = true;
      if (useScreenFlash) _screenFlash = true;
    });
    try {
      // Даём белому экрану отрисоваться и подсветить кадр.
      if (useScreenFlash) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      final shot = await controller.takePicture();
      final file = await _cropToSquare(shot);
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _screenFlash = false;
        _error = 'Не удалось сделать снимок: $e';
      });
    }
  }

  /// Центр-кроп снимка в квадрат + сжатие в JPEG q85, ≤1600px.
  Future<File> _cropToSquare(XFile shot) async {
    final bytes = await shot.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Не удалось декодировать снимок');
    }
    final side = min(decoded.width, decoded.height);
    final cropped = img.copyCrop(
      decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = side > _maxDimension
        ? img.copyResize(cropped, width: _maxDimension, height: _maxDimension)
        : cropped;
    final jpg = img.encodeJpg(resized, quality: _jpegQuality);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/cam_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return File(path).writeAsBytes(jpg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(child: _buildBody(context)),
          // Экранная вспышка для фронталки — белый оверлей во весь экран.
          if (_screenFlash)
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_permissionDenied) {
      return const _Message(
        text: 'Нет доступа к камере. Разрешите его в настройках приложения.',
        actionLabel: 'Открыть настройки',
        onAction: openAppSettings,
      );
    }
    if (_error != null) {
      return _Message(
        text: _error!,
        actionLabel: 'Закрыть',
        onAction: () => Navigator.of(context).pop(),
      );
    }
    final controller = _controller;
    // Во время инициализации/смены камеры — чёрный лоадер (без белого мига).
    if (_initializing ||
        _switching ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final side = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const Spacer(),
        // Квадратная рамка превью 1:1 с тап-фокусом.
        SizedBox(
          width: side,
          height: side,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _focusOnTap(d.localPosition, side),
            child: Stack(
              children: [
                ClipRect(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: side,
                        height: side * controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
                if (_focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 28,
                    top: _focusPoint!.dy - 28,
                    child: const _FocusReticle(),
                  ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _Controls(
          capturing: _capturing,
          canFlip: _cameras.length > 1,
          flashIcon: _flashIcon,
          onCapture: _capture,
          onFlip: _flipCamera,
          onFlash: _cycleFlash,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FocusReticle extends StatelessWidget {
  const _FocusReticle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.capturing,
    required this.canFlip,
    required this.flashIcon,
    required this.onCapture,
    required this.onFlip,
    required this.onFlash,
  });

  final bool capturing;
  final bool canFlip;
  final IconData flashIcon;
  final VoidCallback onCapture;
  final VoidCallback onFlip;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 48,
            child: IconButton(
              icon: Icon(flashIcon, color: Colors.white, size: 28),
              tooltip: 'Вспышка',
              onPressed: capturing ? null : onFlash,
            ),
          ),
          GestureDetector(
            onTap: capturing ? null : onCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.primary, width: 4),
              ),
              child: capturing
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : null,
            ),
          ),
          SizedBox(
            width: 48,
            child: canFlip
                ? IconButton(
                    icon: const Icon(
                      Icons.cameraswitch_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: capturing ? null : onFlip,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
