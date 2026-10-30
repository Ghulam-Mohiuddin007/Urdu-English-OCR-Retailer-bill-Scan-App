import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/ocr_scan_controller.dart';
import '../../controllers/ocr_scan_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../result/ocr_result_table_screen.dart';
import 'scanning_animation_overlay.dart';

class OcrScannerScreen extends ConsumerWidget {
  const OcrScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ocrScanControllerProvider);
    final controller = ref.read(ocrScanControllerProvider.notifier);

    // Auto-navigate to result table screen when OCR data is ready
    ref.listen<OcrScanState>(ocrScanControllerProvider, (previous, next) {
      if (next is OcrScanDataReady && previous is! OcrScanDataReady) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OcrResultTableScreen(
              initialResult: next.result,
              croppedImage: next.croppedImage,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentMint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 20,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 13,
                  color: AppTheme.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  'آف لائن موڈ',
                  style: AppTheme.urduTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Scrollable Ingestion Dashboard
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Greeting & Brand Header Card
                  _buildHeaderHeroCard(),
                  const SizedBox(height: 24),

                  // Ingestion Options Title
                  Text(
                    'دستاویز شامل کریں / Ingest Bill',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Two Prominent Interactive Ingestion Cards
                  Row(
                    children: [
                      // 1. Camera Capture Card
                      Expanded(
                        child: _buildIngestionCard(
                          context: context,
                          titleUrdu: 'کیمرہ سے تصویر لیں',
                          titleEn: 'Take Photo',
                          subtitle: 'Live Camera Capture',
                          icon: Icons.camera_alt_rounded,
                          isPrimary: true,
                          onTap: () => controller.captureFromCamera(context),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // 2. Gallery / Document Upload Card
                      Expanded(
                        child: _buildIngestionCard(
                          context: context,
                          titleUrdu: 'گیلری سے منتخب کریں',
                          titleEn: 'Upload Document',
                          subtitle: 'Pick Existing Slip',
                          icon: Icons.photo_library_rounded,
                          isPrimary: false,
                          onTap: () => controller.pickFromGallery(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Sample Bills for Immediate Offline Testing
                  _buildSampleBillsSection(context, controller),
                  const SizedBox(height: 24),

                  // Scanning Best Practices / Tips Card
                  _buildBestPracticesCard(),
                  const SizedBox(height: 24),

                  // Error State Banner (if any)
                  if (state is OcrScanError) ...[
                    _buildErrorBanner(context, controller, state),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // 60fps Laser Scanning Animation Overlay (during processing)
          if (state is OcrScanProcessing)
            Positioned.fill(
              child: ScanningAnimationOverlay(
                imageFile: state.croppedImage,
                statusUrdu: state.statusUrdu,
                statusEn: state.statusEn,
                stageIndex: state.stageIndex,
              ),
            ),
        ],
      ),
    );
  }

  /// Header Hero Card
  Widget _buildHeaderHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryDark,
            AppTheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 5),
                    Text(
                      'AI Accuracy ~100%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.analytics_outlined,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'اردو اور انگریزی رسید اسکینر',
            style: AppTheme.urduTextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Smart retail document digitizer for Ghalla Mandi, wholesalers & shopkeepers.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Ingestion Action Card (Camera / Gallery)
  Widget _buildIngestionCard({
    required BuildContext context,
    required String titleUrdu,
    required String titleEn,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? AppTheme.primary.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppTheme.accentMint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: isPrimary ? Colors.white : AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                titleUrdu,
                style: AppTheme.urduTextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                titleEn,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isPrimary ? Colors.white70 : AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sample Slip Quick-Test Section
  Widget _buildSampleBillsSection(BuildContext context, OcrScanController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'تجرباتی بل برائے ٹیسٹ (Quick Test Samples)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Test with real wholesale commodity receipts:',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSampleChip(
                label: 'Sample 1 (#17405)',
                onTap: () => _testWithSampleFile(controller, 'sample.jpeg'),
              ),
              const SizedBox(width: 8),
              _buildSampleChip(
                label: 'Sample 2 (#17565)',
                onTap: () => _testWithSampleFile(controller, 'sample2.jpeg'),
              ),
              const SizedBox(width: 8),
              _buildSampleChip(
                label: 'Sample 3 (#17287)',
                onTap: () => _testWithSampleFile(controller, 'sample3.jpeg'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSampleChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  void _testWithSampleFile(OcrScanController controller, String sampleFileName) {
    // Check if sample image exists on disk in current workspace
    final samplePath = 'd:\\OCR project\\$sampleFileName';
    final file = File(samplePath);
    if (file.existsSync()) {
      controller.startOcrProcessing(file);
    } else {
      // Fallback with virtual path
      controller.startOcrProcessing(File(sampleFileName));
    }
  }

  /// Best Practices Tip Card
  Widget _buildBestPracticesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 18, color: AppTheme.warning),
              const SizedBox(width: 8),
              Text(
                'بہترین اسکیننگ کے اہم نکات (Tips for Best Results)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTipBullet('بل کو ہموار اور روشن جگہ پر رکھیں۔ (Keep slip flat under good lighting)'),
          const SizedBox(height: 6),
          _buildTipBullet('کراپ اسکرین پر بل کے چاروں کونے ٹیبل کے مطابق ملائیں۔ (Align crop corners)'),
          const SizedBox(height: 6),
          _buildTipBullet('کیمرہ سیدھا اوپر رکھ کر تصویر کھینچیں۔ (Hold phone parallel to avoid skew)'),
        ],
      ),
    );
  }

  Widget _buildTipBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.check_circle_outline, size: 14, color: AppTheme.accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Error Banner with Retry
  Widget _buildErrorBanner(
    BuildContext context,
    OcrScanController controller,
    OcrScanError errorState,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorState.errorMessage,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (errorState.failedImage != null)
            TextButton(
              onPressed: () => controller.startOcrProcessing(errorState.failedImage!),
              child: const Text('دوبارہ کوشش'),
            ),
        ],
      ),
    );
  }
}

