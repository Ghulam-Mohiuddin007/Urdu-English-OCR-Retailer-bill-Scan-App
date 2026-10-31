import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CameraShutterButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isBusy;
  final String labelUrdu;
  final String labelEn;

  const CameraShutterButton({
    super.key,
    required this.onTap,
    this.isBusy = false,
    this.labelUrdu = 'کیمرہ سے بل کی تصویر لیں',
    this.labelEn = 'Capture Receipt',
  });

  @override
  State<CameraShutterButton> createState() => _CameraShutterButtonState();
}

class _CameraShutterButtonState extends State<CameraShutterButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isBusy) {
          setState(() => _isPressed = true);
          AppHaptics.selection();
        }
      },
      onTapUp: (_) {
        if (!widget.isBusy) {
          setState(() => _isPressed = false);
          AppHaptics.medium();
          widget.onTap();
        }
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _isPressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glowing halo
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.6),
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Inner tactile shutter disk
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _isPressed ? 62 : 68,
                  height: _isPressed ? 62 : 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isBusy
                          ? [Colors.grey.shade700, Colors.grey.shade800]
                          : [
                              Colors.white,
                              const Color(0xFFD1FAE5),
                              AppTheme.accentEmerald,
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: widget.isBusy
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.accentEmerald,
                              ),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: AppTheme.darkCanvas,
                          size: 30,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.labelUrdu,
            style: AppTheme.urduTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

