import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ScanningAnimationOverlay extends StatefulWidget {
  final File? imageFile;
  final File? croppedImage;
  final String statusUrdu;
  final String statusEn;
  final int stageIndex;

  const ScanningAnimationOverlay({
    super.key,
    this.imageFile,
    this.croppedImage,
    required this.statusUrdu,
    required this.statusEn,
    required this.stageIndex,
  });

  File get effectiveImage => croppedImage ?? imageFile!;

  @override
  State<ScanningAnimationOverlay> createState() =>
      _ScanningAnimationOverlayState();
}

class _ScanningAnimationOverlayState extends State<ScanningAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'OCR ENGINE SCANNING / تجزیہ جاری ہے',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Document Preview with Laser Scan
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cropped Bill Image Preview
                    Image.file(
                      widget.effectiveImage,
                      fit: BoxFit.contain,
                    ),

                    // Dark Tint overlay for contrast with laser
                    Container(
                      color: Colors.black.withValues(alpha: 0.25),
                    ),

                    // Animated Laser Beam & Viewfinder
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: LaserScannerPainter(
                            progress: _laserAnimation.value,
                            laserColor: AppTheme.accent,
                          ),
                          child: Container(),
                        );
                      },
                    ),

                    // Target Corner Reticles
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: ViewfinderCornerPainter(
                            cornerColor: AppTheme.accent,
                            cornerLength: 28,
                            strokeWidth: 3.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Progressive Dynamic Status Card
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<int>(widget.stageIndex),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Slate 800
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stage Indicators & Pulsing Dot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'STAGE ${widget.stageIndex + 1} OF 4',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Urdu Status Message
                    Text(
                      widget.statusUrdu,
                      textAlign: TextAlign.center,
                      style: AppTheme.urduTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // English Status Message
                    Text(
                      widget.statusEn,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Segmented Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (widget.stageIndex + 1) / 4.0,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.accent,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter for the 60fps Neon Laser Beam with Vertical Glow Trail
class LaserScannerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color laserColor;

  LaserScannerPainter({
    required this.progress,
    required this.laserColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    // 1. Draw glowing gradient trail
    final trailHeight = size.height * 0.12;
    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          laserColor.withValues(alpha: 0.02),
          laserColor.withValues(alpha: 0.18),
        ],
      ).createShader(Rect.fromLTWH(0, y - trailHeight, size.width, trailHeight));

    canvas.drawRect(
      Rect.fromLTWH(0, y - trailHeight, size.width, trailHeight),
      trailPaint,
    );

    // 2. Draw outer laser blur line
    final outerLinePaint = Paint()
      ..color = laserColor.withValues(alpha: 0.6)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawLine(Offset(0, y), Offset(size.width, y), outerLinePaint);

    // 3. Draw core neon laser line
    final coreLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), coreLinePaint);

    // 4. Draw side flare dots
    final flarePaint = Paint()
      ..color = laserColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(4, y), 5, flarePaint);
    canvas.drawCircle(Offset(size.width - 4, y), 5, flarePaint);
  }

  @override
  bool shouldRepaint(covariant LaserScannerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.laserColor != laserColor;
  }
}

/// CustomPainter for Document Reticle Corners
class ViewfinderCornerPainter extends CustomPainter {
  final Color cornerColor;
  final double cornerLength;
  final double strokeWidth;

  const ViewfinderCornerPainter({
    required this.cornerColor,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const pad = 12.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(pad, pad + cornerLength)
        ..lineTo(pad, pad)
        ..lineTo(pad + cornerLength, pad),
      paint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - cornerLength, pad)
        ..lineTo(size.width - pad, pad)
        ..lineTo(size.width - pad, pad + cornerLength),
      paint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(pad, size.height - pad - cornerLength)
        ..lineTo(pad, size.height - pad)
        ..lineTo(pad + cornerLength, size.height - pad),
      paint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - cornerLength, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ViewfinderCornerPainter oldDelegate) => false;
}

