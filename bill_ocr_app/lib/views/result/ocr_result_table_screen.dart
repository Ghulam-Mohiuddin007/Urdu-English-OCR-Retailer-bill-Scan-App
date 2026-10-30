import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/ocr_scan_controller.dart';
import '../../controllers/ocr_scan_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/ocr_bill_item.dart';
import '../../models/ocr_scan_result.dart';
import '../../services/excel_export_service.dart';

class OcrResultTableScreen extends ConsumerStatefulWidget {
  final OcrScanResult initialResult;
  final File croppedImage;

  const OcrResultTableScreen({
    super.key,
    required this.initialResult,
    required this.croppedImage,
  });

  @override
  ConsumerState<OcrResultTableScreen> createState() =>
      _OcrResultTableScreenState();
}

class _OcrResultTableScreenState extends ConsumerState<OcrResultTableScreen> {
  File? _lastExportedExcelFile;

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(ocrScanControllerProvider);
    final controller = ref.read(ocrScanControllerProvider.notifier);

    // Get current result from state or fallback to widget.initialResult
    final result = (scanState is OcrScanDataReady)
        ? scanState.result
        : (scanState is OcrScanExportSuccess)
            ? scanState.result
            : widget.initialResult;

    final isExporting = (scanState is OcrScanDataReady && scanState.isExporting);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'تصدیق برائے انوینٹری / Bill Verification',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Bill #${result.billNo} • ${result.date}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'دوبارہ اسکین کریں (Scan Again)',
            onPressed: () {
              controller.reset();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Bill Metadata & Summary Banner
                    _buildBillMetadataCard(result),
                    const SizedBox(height: 16),

                    // 2. Interactive Editable Data Table
                    _buildDataTableCard(result, controller),
                    const SizedBox(height: 16),

                    // 3. Quick Tips Banner
                    _buildQuickTipsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            _buildBottomActionBar(context, controller, result, isExporting),
          ],
        ),
      ),
    );
  }

  /// Bill Header Card showing Customer, Items count, Total Weight & Subtotal
  Widget _buildBillMetadataCard(OcrScanResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Customer & Date Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentMint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.customer,
                      style: AppTheme.urduTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      'بل نمبر: ${result.billNo}  •  تاریخ: ${result.date}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '100% تصدیق شدہ',
                      style: AppTheme.urduTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),

          // Metrics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricChip(
                label: 'کل آئٹمز (Items)',
                value: '${result.items.length}',
                icon: Icons.inventory_2_outlined,
              ),
              Container(width: 1, height: 32, color: AppTheme.border),
              _buildMetricChip(
                label: 'کل وزن (Weight)',
                value: Formatters.formatWeight(result.totalWeight),
                icon: Icons.scale_outlined,
              ),
              Container(width: 1, height: 32, color: AppTheme.border),
              _buildMetricChip(
                label: 'کل بل رقم (Subtotal)',
                value: Formatters.formatCurrency(result.subtotal),
                icon: Icons.payments_outlined,
                isHighlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isHighlight ? AppTheme.primary : AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Interactive Editable Data Table Card
  Widget _buildDataTableCard(OcrScanResult result, OcrScanController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title & Add Item Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.table_chart_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'خریداری کی تفصیل (Purchased Items)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => controller.addNewItem(),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: Text(
                    'نیا آئٹم',
                    style: AppTheme.urduTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Scrollable Horizontal Table to prevent overflows
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 540),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceVariant),
                headingTextStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                dataTextStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                columnSpacing: 18,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('آئٹم نام / Item')),
                  DataColumn(label: Text('وزن (kg)'), numeric: true),
                  DataColumn(label: Text('ریٹ (Rate)'), numeric: true),
                  DataColumn(label: Text('کل رقم (Total)'), numeric: true),
                  DataColumn(label: Text('تبدیلی / Edit')),
                ],
                rows: List.generate(result.items.length, (index) {
                  final item = result.items[index];
                  final isEven = index % 2 == 0;

                  return DataRow(
                    color: WidgetStateProperty.all(
                      isEven ? Colors.transparent : AppTheme.surfaceVariant.withValues(alpha: 0.35),
                    ),
                    cells: [
                      // S.No
                      DataCell(
                        Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      // Item Name (Urdu)
                      DataCell(
                        InkWell(
                          onTap: () => _showEditDialog(context, controller, index, item),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.itemName,
                                style: AppTheme.urduTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_outlined, size: 12, color: AppTheme.textTertiary),
                            ],
                          ),
                        ),
                      ),
                      // Weight
                      DataCell(
                        InkWell(
                          onTap: () => _showEditDialog(context, controller, index, item),
                          child: Text(
                            Formatters.formatQuantity(item.weight),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      // Rate
                      DataCell(
                        InkWell(
                          onTap: () => _showEditDialog(context, controller, index, item),
                          child: Text(
                            Formatters.formatCurrency(item.unitPrice),
                          ),
                        ),
                      ),
                      // Line Total
                      DataCell(
                        Text(
                          Formatters.formatCurrency(item.totalPrice),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      // Action Delete / Edit
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                              onPressed: () => _showEditDialog(context, controller, index, item),
                              tooltip: 'ترمیم کریں',
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppTheme.error,
                              ),
                              onPressed: () => controller.deleteItem(index),
                              tooltip: 'حذف کریں',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Informative Tip Banner
  Widget _buildQuickTipsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentMint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'حسابی فارمولا: کل رقم = وزن × ریٹ ÷ 40 (من کا حساب)۔ کسی بھی خانے پر کلک کر کے قیمت تبدیل کر سکتے ہیں۔',
              style: AppTheme.urduTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Action Bar with Excel Generation and Direct Share
  Widget _buildBottomActionBar(
    BuildContext context,
    OcrScanController controller,
    OcrScanResult result,
    bool isExporting,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(
          top: BorderSide(color: AppTheme.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Share Button
          OutlinedButton.icon(
            onPressed: isExporting
                ? null
                : () async {
                    try {
                      final file = _lastExportedExcelFile ??
                          await controller.exportToExcel();
                      if (file != null) {
                        _lastExportedExcelFile = file;
                        await ExcelExportService.shareExcelFile(file);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showSnackBar(context, 'شیئرنگ میں خرابی: $e', isError: true);
                      }
                    }
                  },
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
          ),
          const SizedBox(width: 12),

          // Primary Export to Excel (.xlsx) Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isExporting
                  ? null
                  : () async {
                      try {
                        final file = await controller.exportToExcel();
                        if (file != null && context.mounted) {
                          _lastExportedExcelFile = file;
                          _showExportSuccessModal(context, file);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showSnackBar(context, 'ایکسل فائل بنانے میں خرابی: $e', isError: true);
                        }
                      }
                    },
              icon: isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.table_view_rounded, size: 20),
              label: Text(
                isExporting ? 'ایکسل بن رہا ہے...' : 'ایکسل بنائیں (Export .xlsx)',
                style: AppTheme.urduTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Keyboard-safe Modal Bottom Sheet for Item Editing
  void _showEditDialog(
    BuildContext context,
    OcrScanController controller,
    int index,
    OcrBillItem item,
  ) {
    final nameController = TextEditingController(text: item.itemName);
    final weightController = TextEditingController(text: item.weight.toString());
    final rateController = TextEditingController(text: item.unitPrice.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'آئٹم کی تفصیل میں ترمیم (Edit Item)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Item Name (Urdu & English)
                TextField(
                  controller: nameController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'آئٹم کا نام (Commodity Name)',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Weight & Qty Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'وزن / Weight (kg)',
                          suffixText: 'kg',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'تعداد / Qty',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Unit Rate (Per Maund / 40kg)
                TextField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ریٹ فی من / Unit Rate (PKR)',
                    prefixText: '₨ ',
                  ),
                ),
                const SizedBox(height: 20),

                // Save Action
                ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim();
                    final newWeight = double.tryParse(weightController.text) ?? item.weight;
                    final newRate = double.tryParse(rateController.text) ?? item.unitPrice;
                    final newQty = double.tryParse(qtyController.text) ?? item.quantity;

                    final updated = item.copyWith(
                      itemName: newName.isNotEmpty ? newName : item.itemName,
                      weight: newWeight,
                      unitPrice: newRate,
                      quantity: newQty,
                    );

                    controller.updateItem(index, updated);
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    'تبدیلی محفوظ کریں (Save Changes)',
                    style: AppTheme.urduTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Success Modal with options to Open Excel or Share
  void _showExportSuccessModal(BuildContext context, File excelFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.accentMint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 40,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ایکسل فائل کامیابی سے بن گئی!',
                style: AppTheme.urduTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Excel file saved to:\n${excelFile.path.split(Platform.pathSeparator).last}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ExcelExportService.shareExcelFile(excelFile);
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share File'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ExcelExportService.openExcelFile(excelFile);
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open Sheet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

