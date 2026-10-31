import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text_direction_helper.dart';

class BilingualTextCard extends StatelessWidget {
  final String text;
  final String? subtitle;
  final double? confidence;
  final VoidCallback? onEdit;
  final bool isEditable;

  const BilingualTextCard({
    super.key,
    required this.text,
    this.subtitle,
    this.confidence,
    this.onEdit,
    this.isEditable = false,
  });

  @override
  Widget build(BuildContext context) {
    final textDirection = TextDirectionHelper.getTextDirection(text);
    final script = TextDirectionHelper.detectScript(text);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration(
        backgroundColor: AppTheme.darkSurface.withValues(alpha: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Script Badge (Urdu / English)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: script == DetectedScript.urdu
                      ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                      : AppTheme.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  script == DetectedScript.urdu ? 'اردو (Nastaliq)' : 'English',
                  style: AppTheme.englishTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: script == DetectedScript.urdu
                        ? AppTheme.accentEmerald
                        : AppTheme.accentGold,
                  ),
                ),
              ),
              const Spacer(),

              // Quick Copy Button
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.textDarkSecondary),
                tooltip: 'کاپی کریں (Copy)',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  AppHaptics.light();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('متن کاپی ہو گیا ہے (Text copied)'),
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),

              if (isEditable && onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.accentEmerald),
                  tooltip: 'ترمیم کریں (Edit)',
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Extracted Text with dynamic RTL/LTR support
          Directionality(
            textDirection: textDirection,
            child: Text(
              text,
              style: script == DetectedScript.urdu
                  ? AppTheme.urduTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkPrimary,
                      height: 1.8,
                    )
                  : AppTheme.englishTextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkPrimary,
                      height: 1.4,
                    ),
            ),
          ),

          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTheme.englishTextStyle(
                fontSize: 12,
                color: AppTheme.textDarkSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

