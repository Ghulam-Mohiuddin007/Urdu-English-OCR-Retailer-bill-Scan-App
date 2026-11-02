import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/history_controller.dart';
import '../../controllers/ocr_scan_controller.dart';
import '../../controllers/ocr_scan_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../history/scan_history_screen.dart';
import '../inventory/inventory_screen.dart';
import '../result/ocr_result_table_screen.dart';
import '../settings/supabase_settings_dialog.dart';
import 'components/camera_shutter_button.dart';
import 'components/viewfinder_reticle.dart';
import 'scanning_animation_overlay.dart';

class OcrScannerScreen extends ConsumerWidget {
  const OcrScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ocrScanControllerProvider);
    final controller = ref.read(ocrScanControllerProvider.notifier);
    final historyState = ref.watch(historyControllerProvider);

    // Auto-navigate to result screen when OCR data is extracted
    ref.listen<OcrScanState>(ocrScanControllerProvider, (previous, next) {
      if (next is OcrScanDataReady && previous is! OcrScanDataReady) {
        AppHaptics.medium();
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

    final isProcessing = state is OcrScanProcessing;
    final capturedImage = state is OcrScanImageCaptured
        ? state.rawImage
        : (state is OcrScanCropping
            ? state.rawImage
            : (state is OcrScanProcessing ? state.croppedImage : null));

    return Scaffold(
      backgroundColor: AppTheme.darkCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Background Viewport & Viewfinder
            ResponsiveContentContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Top Glass Navigation Bar
                  _buildTopBar(context, historyCount: historyState.allScans.length),

                  // Center Document Viewfinder Reticle (Responsive fit within available viewport)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Center(
                        child: ViewfinderReticle(
                          isScanning: isProcessing,
                          previewContent: capturedImage != null
                              ? Image.file(capturedImage, fit: BoxFit.cover)
                              : _buildEmptyViewfinderGuide(),
                        ),
                      ),
                    ),
                  ),

                  // Guidance Chip
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.center_focus_strong_rounded,
                          size: 15,
                          color: AppTheme.accentEmerald,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'بل کو فریم کے اندر سیدھا رکھیں (Align bill inside)',
                          style: AppTheme.urduTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDarkSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Tactile Control Dock
                  _buildControlDock(context, controller, isBusy: isProcessing),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // 2. Full Laser Scan Animation Overlay (active during OCR inference)
            if (isProcessing)
              ScanningAnimationOverlay(
                croppedImage: state.croppedImage,
                statusUrdu: state.statusUrdu,
                statusEn: state.statusEn,
                stageIndex: state.stageIndex,
              ),

            // 3. Error Banner Snack
            if (state is OcrScanError)
              Positioned(
                top: 70,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage,
                          style: AppTheme.urduTextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        onPressed: controller.resetToInitial,
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

  Widget _buildTopBar(BuildContext context, {required int historyCount}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Brand Icon & Name
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: AppTheme.accentEmerald,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.englishTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDarkPrimary,
                  ),
                ),
                Text(
                  'رسید اسکینر (Urdu + English)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.urduTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDarkMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Supabase Cloud Status Indicator
          InkWell(
            onTap: () {
              AppHaptics.light();
              showDialog(
                context: context,
                builder: (_) => const SupabaseSettingsDialog(),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF3ECF8E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3ECF8E).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_sync_rounded,
                    size: 13,
                    color: Color(0xFF3ECF8E),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Supabase',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3ECF8E),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Inventory Ledger Shortcut
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                size: 18,
                color: AppTheme.accentGold,
              ),
            ),
            tooltip: 'انوینٹری اسٹاک (Inventory)',
            onPressed: () {
              AppHaptics.light();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              );
            },
          ),

          // Scan Vault / History Shortcut with Badge
          IconButton(
            icon: Badge(
              label: Text('$historyCount'),
              isLabelVisible: historyCount > 0,
              backgroundColor: AppTheme.accentEmerald,
              textColor: Colors.black,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 18,
                  color: AppTheme.textDarkPrimary,
                ),
              ),
            ),
            tooltip: 'محفوظ شدہ رسیدیں (Bill History)',
            onPressed: () {
              AppHaptics.light();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyViewfinderGuide() {
    return Container(
      color: AppTheme.darkSurface.withValues(alpha: 0.4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_rounded,
              size: 52,
              color: AppTheme.accentEmerald.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'گھلہ منڈی بل یا پرچون رسید سامنے لائیں',
              style: AppTheme.urduTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDarkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlDock(
    BuildContext context,
    OcrScanController controller, {
    required bool isBusy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Gallery Image Picker Button
          _DockIconButton(
            icon: Icons.photo_library_rounded,
            labelUrdu: 'گیلری سے منتخب',
            labelEn: 'Gallery',
            onTap: () => controller.pickFromGallery(context),
            isBusy: isBusy,
          ),

          // 2. Primary Camera Shutter Button with tactile haptics
          CameraShutterButton(
            onTap: () => controller.captureFromCamera(context),
            isBusy: isBusy,
          ),

          // 3. Demo / Pre-calibrated Slip Quick Test Button
          _DockIconButton(
            icon: Icons.auto_awesome_rounded,
            labelUrdu: 'ٹیسٹ بل لوڈ کریں',
            labelEn: 'Sample Slip',
            accentColor: AppTheme.accentGold,
            onTap: () => controller.processSampleBill(context),
            isBusy: isBusy,
          ),
        ],
      ),
    );
  }
}

class _DockIconButton extends StatefulWidget {
  final IconData icon;
  final String labelUrdu;
  final String labelEn;
  final VoidCallback onTap;
  final bool isBusy;
  final Color? accentColor;

  const _DockIconButton({
    required this.icon,
    required this.labelUrdu,
    required this.labelEn,
    required this.onTap,
    this.isBusy = false,
    this.accentColor,
  });

  @override
  State<_DockIconButton> createState() => _DockIconButtonState();
}

class _DockIconButtonState extends State<_DockIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? AppTheme.textDarkPrimary;

    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isBusy) {
          setState(() => _pressed = true);
          AppHaptics.selection();
        }
      },
      onTapUp: (_) {
        if (!widget.isBusy) {
          setState(() => _pressed = false);
          widget.onTap();
        }
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _pressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.labelUrdu,
            style: AppTheme.urduTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDarkSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
