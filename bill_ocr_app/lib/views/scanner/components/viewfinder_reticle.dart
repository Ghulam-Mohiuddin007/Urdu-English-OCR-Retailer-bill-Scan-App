import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ViewfinderReticle extends StatefulWidget {
  final bool isScanning;
  final Widget? previewContent;

  const ViewfinderReticle({
    super.key,
    this.isScanning = false,
    this.previewContent,
  });

  @override
  State<ViewfinderReticle> createState() => _ViewfinderReticleState();
}

class _ViewfinderReticleState extends State<ViewfinderReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        children: [
          // Background preview content (if captured or placeholder)
          if (widget.previewContent != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: widget.previewContent!,
              ),
            ),

          // Reticle Frame with corner brackets
          Positioned.fill(
            child: CustomPaint(
              painter: _ReticleCornerPainter(
                cornerColor: widget.isScanning
                    ? AppTheme.accentCyan
                    : AppTheme.accentEmerald,
                strokeWidth: 3.5,
                cornerLength: 32.0,
              ),
            ),
          ),

          // Animated Scanning Laser Beam (active during OCR scanning)
          if (widget.isScanning)
            AnimatedBuilder(
              animation: _laserAnimation,
              builder: (context, child) {
                return Align(
                  alignment: Alignment(0, (_laserAnimation.value * 2) - 1.0),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppTheme.accentCyan,
                          Colors.white,
                          AppTheme.accentEmerald,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withValues(alpha: 0.8),
                          blurRadius: 16,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: AppTheme.accentEmerald.withValues(alpha: 0.5),
                          blurRadius: 28,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReticleCornerPainter extends CustomPainter {
  final Color cornerColor;
  final double strokeWidth;
  final double cornerLength;

  _ReticleCornerPainter({
    required this.cornerColor,
    required this.strokeWidth,
    required this.cornerLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const r = 24.0;
    final w = size.width;
    final h = size.height;

    // Top Left
    final tlPath = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tlPath, paint);

    // Top Right
    final trPath = Path()
      ..moveTo(w - cornerLength, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, cornerLength);
    canvas.drawPath(trPath, paint);

    // Bottom Left
    final blPath = Path()
      ..moveTo(0, h - cornerLength)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: const Radius.circular(r))
      ..lineTo(cornerLength, h);
    canvas.drawPath(blPath, paint);

    // Bottom Right
    final brPath = Path()
      ..moveTo(w - cornerLength, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r))
      ..lineTo(w, h - cornerLength);
    canvas.drawPath(brPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ReticleCornerPainter oldDelegate) {
    return oldDelegate.cornerColor != cornerColor;
  }
}

