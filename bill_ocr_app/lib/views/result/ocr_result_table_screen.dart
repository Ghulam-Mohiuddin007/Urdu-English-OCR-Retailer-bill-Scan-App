import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/history_controller.dart';
import '../../controllers/ocr_scan_controller.dart';
import '../../controllers/ocr_scan_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/ocr_bill_item.dart';
import '../../models/ocr_scan_result.dart';
import '../../models/scan_history_entry.dart';
import '../../services/excel_export_service.dart';
import '../../services/scan_history_service.dart';
import 'components/bilingual_text_card.dart';

class OcrResultTableScreen extends ConsumerStatefulWidget {
  final OcrScanResult initialResult;
  final File? croppedImage;

  const OcrResultTableScreen({
    super.key,
    required this.initialResult,
    this.croppedImage,
  });

  @override
  ConsumerState<OcrResultTableScreen> createState() =>
      _OcrResultTableScreenState();
}

class _OcrResultTableScreenState extends ConsumerState<OcrResultTableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  File? _lastExportedExcelFile;
  bool _isSavingToVault = false;
  bool _hasSavedToVault = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(ocrScanControllerProvider);
    final controller = ref.read(ocrScanControllerProvider.notifier);

    // Current working bill result
    final result = (scanState is OcrScanDataReady)
        ? scanState.result
        : (scanState is OcrScanExportSuccess)
            ? scanState.result
            : widget.initialResult;

    final isExporting = (scanState is OcrScanDataReady && scanState.isExporting);

    return Scaffold(
      backgroundColor: AppTheme.darkCanvas,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'رسید کا جائزہ برائے انوینٹری',
              style: AppTheme.urduTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDarkPrimary,
                height: 1.3,
              ),
            ),
            Text(
              'Bill #${result.billNo} • ${result.date}',
              style: AppTheme.englishTextStyle(
                fontSize: 12,
                color: AppTheme.textDarkMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textDarkSecondary),
            tooltip: 'دوبارہ اسکین کریں',
            onPressed: () {
              AppHaptics.selection();
              controller.reset();
              Navigator.of(context).pop();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentEmerald,
          indicatorWeight: 3,
          labelColor: AppTheme.accentEmerald,
          unselectedLabelColor: AppTheme.textDarkSecondary,
          labelStyle: AppTheme.urduTextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.2),
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_rounded, size: 18), text: 'ٹیبل موڈ (Structured Table)'),
            Tab(icon: Icon(Icons.translate_rounded, size: 18), text: 'متن کا بہاؤ (Bilingual Stream)'),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // 1. Bill Header Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildBillHeaderCard(result),
              ),

              // 2. Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab A: Interactive Editable Table
                    _buildTableTab(result, controller),

                    // Tab B: Bilingual Stream Cards (Urdu RTL & English LTR)
                    _buildBilingualStreamTab(result, controller),
                  ],
                ),
              ),

              // 3. Bottom Floating Action Dock (Excel / Share / Save)
              _buildBottomActionDock(result, controller, isExporting),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillHeaderCard(OcrScanResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration(
        backgroundColor: AppTheme.darkSurface,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_rounded, size: 20, color: AppTheme.accentEmerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.urduTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDarkPrimary,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      'غلہ منڈی بل نمبر: ${result.billNo}',
                      style: AppTheme.urduTextStyle(
                        fontSize: 11,
                        color: AppTheme.textDarkMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatCurrency(result.subtotal),
                    style: AppTheme.englishTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentGold,
                      tabularNumbers: true,
                    ),
                  ),
                  Text(
                    '${result.totalWeight} کلو (${AppFormatters.formatMaunds(result.totalWeight)})',
                    style: AppTheme.englishTextStyle(
                      fontSize: 11,
                      color: AppTheme.textDarkSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableTab(OcrScanResult result, OcrScanController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Items Table Container
          Container(
            decoration: AppTheme.glassCardDecoration(
              backgroundColor: AppTheme.darkSurface,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  horizontalMargin: 14,
                  headingRowColor: WidgetStateProperty.all(
                    AppTheme.darkSurfaceElevated,
                  ),
                  headingTextStyle: AppTheme.urduTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentEmerald,
                    height: 1.2,
                  ),
                  columns: const [
                    DataColumn(label: Text('نام جنس (Item)')),
                    DataColumn(label: Text('وزن (kg)'), numeric: true),
                    DataColumn(label: Text('ریٹ / 40 کلو'), numeric: true),
                    DataColumn(label: Text('کل رقم (Rs)'), numeric: true),
                    DataColumn(label: Text('')),
                  ],
                  rows: List.generate(result.items.length, (index) {
                    final item = result.items[index];
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            item.itemName,
                            style: AppTheme.urduTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDarkPrimary,
                              height: 1.3,
                            ),
                          ),
                          onTap: () => _openEditItemSheet(context, controller, index, item),
                        ),
                        DataCell(
                          Text(
                            '${item.weight}',
                            style: AppTheme.englishTextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              tabularNumbers: true,
                            ),
                          ),
                          onTap: () => _openEditItemSheet(context, controller, index, item),
                        ),
                        DataCell(
                          Text(
                            item.unitPrice.toStringAsFixed(0),
                            style: AppTheme.englishTextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              tabularNumbers: true,
                            ),
                          ),
                          onTap: () => _openEditItemSheet(context, controller, index, item),
                        ),
                        DataCell(
                          Text(
                            AppFormatters.formatCurrency(item.totalPrice),
                            style: AppTheme.englishTextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentGold,
                              tabularNumbers: true,
                            ),
                          ),
                          onTap: () => _openEditItemSheet(context, controller, index, item),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.accentEmerald),
                            onPressed: () => _openEditItemSheet(context, controller, index, item),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Add New Row Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentEmerald,
              side: const BorderSide(color: AppTheme.accentEmerald),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'نیا آئٹم شامل کریں (Add Row)',
              style: AppTheme.urduTextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2),
            ),
            onPressed: () {
              AppHaptics.light();
              controller.addNewItem();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBilingualStreamTab(OcrScanResult result, OcrScanController controller) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: result.items.length,
      itemBuilder: (context, index) {
        final item = result.items[index];
        return BilingualTextCard(
          text: item.itemName,
          subtitle:
              'وزن: ${item.weight} kg • ریٹ: Rs. ${item.unitPrice.toStringAsFixed(0)} / 40kg • رقم: Rs. ${item.totalPrice.toStringAsFixed(0)}',
          confidence: 0.98,
          isEditable: true,
          onEdit: () => _openEditItemSheet(context, controller, index, item),
        );
      },
    );
  }

  Widget _buildBottomActionDock(
    OcrScanResult result,
    OcrScanController controller,
    bool isExporting,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // 1. Export Excel Button
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.file_download_rounded, size: 20),
              label: Text(
                'ایکسل ڈاؤن لوڈ (.xlsx)',
                style: AppTheme.urduTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              onPressed: isExporting
                  ? null
                  : () async {
                      AppHaptics.medium();
                      final file = await controller.exportToExcel();
                      if (file != null) {
                        _lastExportedExcelFile = file;
                        await ExcelExportService.openExcelFile(file);
                      }
                    },
            ),
          ),
          const SizedBox(width: 8),

          // 2. Share Button
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.darkSurfaceElevated,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.share_rounded, color: AppTheme.textDarkPrimary, size: 20),
            tooltip: 'شیئر کریں (Share)',
            onPressed: () async {
              AppHaptics.light();
              final file = _lastExportedExcelFile ?? await controller.exportToExcel();
              if (file != null) {
                await controller.shareExcelFile(file);
              }
            },
          ),
          const SizedBox(width: 8),

          // 3. Save to Vault Action
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: _hasSavedToVault
                  ? AppTheme.accentEmerald.withValues(alpha: 0.2)
                  : AppTheme.darkSurfaceElevated,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isSavingToVault
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentEmerald),
                  )
                : Icon(
                    _hasSavedToVault ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                    color: _hasSavedToVault ? AppTheme.accentEmerald : AppTheme.textDarkPrimary,
                    size: 20,
                  ),
            tooltip: 'والٹ میں محفوظ کریں (Save to Vault)',
            onPressed: (_isSavingToVault || _hasSavedToVault)
                ? null
                : () async {
                    setState(() => _isSavingToVault = true);
                    AppHaptics.medium();
                    try {
                      final entry = ScanHistoryEntry.fromScanResult(
                        result,
                        fullImagePath: widget.croppedImage?.path,
                        rawText: result.items.map((i) => i.itemName).join(', '),
                      );
                      await ScanHistoryService.saveScan(
                        entry,
                        originalFile: widget.croppedImage,
                      );
                      ref.read(historyControllerProvider.notifier).loadHistory();
                      setState(() {
                        _isSavingToVault = false;
                        _hasSavedToVault = true;
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('رسید کامیابی سے محفوظ ہو گئی (Saved to Vault)'),
                          duration: Duration(milliseconds: 1500),
                        ),
                      );
                    } catch (e) {
                      setState(() => _isSavingToVault = false);
                    }
                  },
          ),
        ],
      ),
    );
  }

  void _openEditItemSheet(
    BuildContext context,
    OcrScanController controller,
    int index,
    OcrBillItem item,
  ) {
    AppHaptics.selection();
    final nameCtrl = TextEditingController(text: item.itemName);
    final weightCtrl = TextEditingController(text: '${item.weight}');
    final rateCtrl = TextEditingController(text: item.unitPrice.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'آئٹم میں ترمیم (Edit Line Item)',
                    style: AppTheme.urduTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDarkPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
                    onPressed: () {
                      controller.deleteItem(index);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Item Name (Urdu / English)
              TextField(
                controller: nameCtrl,
                style: AppTheme.urduTextStyle(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'نام جنس / Item Name',
                  labelStyle: AppTheme.englishTextStyle(color: AppTheme.textDarkMuted),
                  filled: true,
                  fillColor: AppTheme.darkSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              // Weight with quick presets
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTheme.englishTextStyle(fontSize: 15, tabularNumbers: true),
                      decoration: InputDecoration(
                        labelText: 'وزن (kg)',
                        labelStyle: AppTheme.englishTextStyle(color: AppTheme.textDarkMuted),
                        filled: true,
                        fillColor: AppTheme.darkSurfaceElevated,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTheme.englishTextStyle(fontSize: 15, tabularNumbers: true),
                      decoration: InputDecoration(
                        labelText: 'ریٹ برائے 40 کلو',
                        labelStyle: AppTheme.englishTextStyle(color: AppTheme.textDarkMuted),
                        filled: true,
                        fillColor: AppTheme.darkSurfaceElevated,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Standard Mandi Bag Weight Presets
              Wrap(
                spacing: 8,
                children: AppConstants.standardWeights.map((w) {
                  return ActionChip(
                    label: Text('${w.toInt()} kg'),
                    labelStyle: AppTheme.englishTextStyle(fontSize: 11, color: Colors.white),
                    backgroundColor: AppTheme.darkSurfaceElevated,
                    onPressed: () {
                      AppHaptics.light();
                      weightCtrl.text = '$w';
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Save Changes Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  AppHaptics.medium();
                  final newWeight = double.tryParse(weightCtrl.text) ?? item.weight;
                  final newRate = double.tryParse(rateCtrl.text) ?? item.unitPrice;
                  final updated = item.copyWith(
                    itemName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : item.itemName,
                    weight: newWeight,
                    unitPrice: newRate,
                  );
                  controller.updateItem(index, updated);
                  Navigator.pop(ctx);
                },
                child: Text(
                  'تبدیلی محفوظ کریں (Save & Recalculate)',
                  style: AppTheme.urduTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
