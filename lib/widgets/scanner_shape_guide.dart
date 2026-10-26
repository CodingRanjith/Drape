import 'package:flutter/material.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';

/// Clothing guide shape drawn in the center of the in-app camera.
enum ScannerShape {
  top,
  bottom,
  shorts,
  skirt,
  dress,
  outerwear,
  shoes,
  bag,
  accessory,
  generic,
}

ScannerShape scannerShapeForCategory(WardrobeCategory? category) {
  if (category == null) return ScannerShape.generic;
  return switch (category) {
    WardrobeCategory.topwear ||
    WardrobeCategory.tshirts ||
    WardrobeCategory.shirts ||
    WardrobeCategory.sweaters ||
    WardrobeCategory.activewear ||
    WardrobeCategory.sleepwear ||
    WardrobeCategory.innerwear =>
      ScannerShape.top,
    WardrobeCategory.bottomwear ||
    WardrobeCategory.jeans ||
    WardrobeCategory.trousers =>
      ScannerShape.bottom,
    WardrobeCategory.shorts => ScannerShape.shorts,
    WardrobeCategory.skirts => ScannerShape.skirt,
    WardrobeCategory.dresses ||
    WardrobeCategory.sarees ||
    WardrobeCategory.ethnicWear =>
      ScannerShape.dress,
    WardrobeCategory.outerwear => ScannerShape.outerwear,
    WardrobeCategory.footwear || WardrobeCategory.sandals => ScannerShape.shoes,
    WardrobeCategory.bags => ScannerShape.bag,
    WardrobeCategory.accessories ||
    WardrobeCategory.jewellery ||
    WardrobeCategory.belts ||
    WardrobeCategory.scarves ||
    WardrobeCategory.caps ||
    WardrobeCategory.socks =>
      ScannerShape.accessory,
  };
}

ScannerShape scannerShapeForGarment(GarmentCategory category) {
  return switch (category) {
    GarmentCategory.top => ScannerShape.top,
    GarmentCategory.bottom => ScannerShape.bottom,
    GarmentCategory.dress => ScannerShape.dress,
    GarmentCategory.outerwear => ScannerShape.outerwear,
    GarmentCategory.shoes => ScannerShape.shoes,
    GarmentCategory.accessory => ScannerShape.accessory,
  };
}

/// Dimmed camera mask with a category silhouette cutout in the center.
class ScannerShapeOverlay extends StatelessWidget {
  const ScannerShapeOverlay({
    super.key,
    required this.shape,
    this.label,
  });

  final ScannerShape shape;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _ScannerMaskPainter(shape: shape),
          ),
          if (label != null && label!.trim().isNotEmpty)
            Align(
              alignment: const Alignment(0, -0.72),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerMaskPainter extends CustomPainter {
  const _ScannerMaskPainter({required this.shape});

  final ScannerShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final guideRect = _guideRect(size);
    final shapePath = _shapePath(guideRect, shape);

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addPath(shapePath, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    canvas.drawPath(
      shapePath,
      Paint()
        ..color = AppColors.terracotta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      shapePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Rect _guideRect(Size size) {
    final side = size.shortestSide * 0.72;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: side,
      height: side * 1.15,
    );
  }

  Path _shapePath(Rect r, ScannerShape shape) {
    return switch (shape) {
      ScannerShape.top => _topPath(r),
      ScannerShape.bottom => _bottomPath(r),
      ScannerShape.shorts => _shortsPath(r),
      ScannerShape.skirt => _skirtPath(r),
      ScannerShape.dress => _dressPath(r),
      ScannerShape.outerwear => _outerwearPath(r),
      ScannerShape.shoes => _shoesPath(r),
      ScannerShape.bag => _bagPath(r),
      ScannerShape.accessory => _accessoryPath(r),
      ScannerShape.generic => Path()
        ..addRRect(
          RRect.fromRectAndRadius(r.deflate(r.width * 0.08), const Radius.circular(22)),
        ),
    };
  }

  Path _topPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    return Path()
      ..moveTo(left + w * 0.28, top + h * 0.18)
      ..lineTo(left + w * 0.38, top + h * 0.08)
      ..quadraticBezierTo(left + w * 0.5, top + h * 0.02, left + w * 0.62, top + h * 0.08)
      ..lineTo(left + w * 0.72, top + h * 0.18)
      ..lineTo(left + w * 0.92, top + h * 0.30)
      ..lineTo(left + w * 0.82, top + h * 0.42)
      ..lineTo(left + w * 0.72, top + h * 0.36)
      ..lineTo(left + w * 0.72, top + h * 0.92)
      ..lineTo(left + w * 0.28, top + h * 0.92)
      ..lineTo(left + w * 0.28, top + h * 0.36)
      ..lineTo(left + w * 0.18, top + h * 0.42)
      ..lineTo(left + w * 0.08, top + h * 0.30)
      ..close();
  }

  Path _bottomPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    return Path()
      ..moveTo(left + w * 0.28, top + h * 0.08)
      ..lineTo(left + w * 0.72, top + h * 0.08)
      ..lineTo(left + w * 0.74, top + h * 0.36)
      ..lineTo(left + w * 0.86, top + h * 0.92)
      ..lineTo(left + w * 0.62, top + h * 0.92)
      ..lineTo(left + w * 0.52, top + h * 0.48)
      ..lineTo(left + w * 0.48, top + h * 0.48)
      ..lineTo(left + w * 0.38, top + h * 0.92)
      ..lineTo(left + w * 0.14, top + h * 0.92)
      ..lineTo(left + w * 0.26, top + h * 0.36)
      ..close();
  }

  Path _shortsPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    return Path()
      ..moveTo(left + w * 0.26, top + h * 0.18)
      ..lineTo(left + w * 0.74, top + h * 0.18)
      ..lineTo(left + w * 0.78, top + h * 0.40)
      ..lineTo(left + w * 0.86, top + h * 0.72)
      ..lineTo(left + w * 0.58, top + h * 0.72)
      ..lineTo(left + w * 0.52, top + h * 0.48)
      ..lineTo(left + w * 0.48, top + h * 0.48)
      ..lineTo(left + w * 0.42, top + h * 0.72)
      ..lineTo(left + w * 0.14, top + h * 0.72)
      ..lineTo(left + w * 0.22, top + h * 0.40)
      ..close();
  }

  Path _skirtPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    return Path()
      ..moveTo(left + w * 0.34, top + h * 0.16)
      ..lineTo(left + w * 0.66, top + h * 0.16)
      ..lineTo(left + w * 0.88, top + h * 0.88)
      ..quadraticBezierTo(left + w * 0.5, top + h * 0.96, left + w * 0.12, top + h * 0.88)
      ..close();
  }

  Path _dressPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    return Path()
      ..moveTo(left + w * 0.30, top + h * 0.16)
      ..lineTo(left + w * 0.40, top + h * 0.08)
      ..quadraticBezierTo(left + w * 0.5, top + h * 0.03, left + w * 0.60, top + h * 0.08)
      ..lineTo(left + w * 0.70, top + h * 0.16)
      ..lineTo(left + w * 0.88, top + h * 0.28)
      ..lineTo(left + w * 0.78, top + h * 0.36)
      ..lineTo(left + w * 0.72, top + h * 0.34)
      ..lineTo(left + w * 0.86, top + h * 0.92)
      ..quadraticBezierTo(left + w * 0.5, top + h * 0.98, left + w * 0.14, top + h * 0.92)
      ..lineTo(left + w * 0.28, top + h * 0.34)
      ..lineTo(left + w * 0.22, top + h * 0.36)
      ..lineTo(left + w * 0.12, top + h * 0.28)
      ..close();
  }

  Path _outerwearPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    return Path()
      ..moveTo(left + w * 0.26, top + h * 0.16)
      ..lineTo(left + w * 0.38, top + h * 0.08)
      ..quadraticBezierTo(left + w * 0.5, top + h * 0.03, left + w * 0.62, top + h * 0.08)
      ..lineTo(left + w * 0.74, top + h * 0.16)
      ..lineTo(left + w * 0.96, top + h * 0.30)
      ..lineTo(left + w * 0.84, top + h * 0.42)
      ..lineTo(left + w * 0.76, top + h * 0.36)
      ..lineTo(left + w * 0.76, top + h * 0.92)
      ..lineTo(left + w * 0.24, top + h * 0.92)
      ..lineTo(left + w * 0.24, top + h * 0.36)
      ..lineTo(left + w * 0.16, top + h * 0.42)
      ..lineTo(left + w * 0.04, top + h * 0.30)
      ..close();
  }

  Path _shoesPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    return Path()
      ..moveTo(left + w * 0.18, top + h * 0.42)
      ..quadraticBezierTo(left + w * 0.18, top + h * 0.28, left + w * 0.36, top + h * 0.28)
      ..lineTo(left + w * 0.72, top + h * 0.30)
      ..quadraticBezierTo(left + w * 0.92, top + h * 0.34, left + w * 0.90, top + h * 0.52)
      ..quadraticBezierTo(left + w * 0.88, top + h * 0.68, left + w * 0.62, top + h * 0.70)
      ..lineTo(left + w * 0.28, top + h * 0.68)
      ..quadraticBezierTo(left + w * 0.16, top + h * 0.64, left + w * 0.18, top + h * 0.42)
      ..close();
  }

  Path _bagPath(Rect r) {
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left + w * 0.22, top + h * 0.34, w * 0.56, h * 0.48),
      const Radius.circular(18),
    );
    return Path()
      ..addRRect(body)
      ..moveTo(left + w * 0.34, top + h * 0.34)
      ..quadraticBezierTo(left + w * 0.36, top + h * 0.18, left + w * 0.50, top + h * 0.18)
      ..quadraticBezierTo(left + w * 0.64, top + h * 0.18, left + w * 0.66, top + h * 0.34);
  }

  Path _accessoryPath(Rect r) {
    final center = r.center;
    final radius = r.shortestSide * 0.28;
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldRepaint(covariant _ScannerMaskPainter oldDelegate) =>
      oldDelegate.shape != shape;
}
