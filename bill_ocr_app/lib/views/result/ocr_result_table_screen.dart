import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../controllers/history_controller.dart';
import '../../controllers/inventory_controller.dart';
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
import '../../services/supabase_storage_service.dart';
import '../settings/supabase_settings_dialog.dart';
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
  bool _isAddingToInventory = false;
  bool _isSyncingCloud = false;

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
              'Bill #${result.billNo} • ${result.billerDate}',
              style: AppTheme.englishTextStyle(
                fontSize: 12,
                color: AppTheme.textDarkMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_rounded, color: AppTheme.accentEmerald),
            tooltip: 'Supabase کلاؤڈ سیٹنگز',
            onPressed: () {
              AppHaptics.light();
              showDialog(
                context: context,
                builder: (_) => const SupabaseSettingsDialog(),
              );
            },
          ),
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
              // 1. Bill Header Summary Card (with Interactive Biller Date & Grand Total)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildBillHeaderCard(result, controller),
              ),

              // 2. Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab A: Interactive Editable Table + Bill Total Breakdown + Inventory Action
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

  Widget _buildBillHeaderCard(OcrScanResult result, OcrScanController controller) {
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
              // Grand Bill Total Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatCurrency(result.grandTotal),
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
          const SizedBox(height: 10),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 8),

          // Biller Date & Inventory/Cloud Status Chips (Responsive Wrap prevents any overflow)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Interactive Biller Date Chip (Requirement 2)
              InkWell(
                onTap: () => _pickBillerDate(result, controller),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.accentCyan),
                      const SizedBox(width: 6),
                      Text(
                        'تاریخ رسید: ${result.billerDate}',
                        style: AppTheme.englishTextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 11, color: AppTheme.textDarkMuted),
                    ],
                  ),
                ),
              ),

              // Inventory status pill (Requirement 4)
              if (result.addedToInventory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.accentEmerald),
                      const SizedBox(width: 4),
                      Text(
                        'انوینٹری میں شامل',
                        style: AppTheme.urduTextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentEmerald,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

              // Cloud sync status pill (Requirement 5)
              if (result.syncedToSupabase)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_done_rounded, size: 12, color: Color(0xFF3ECF8E)),
                      const SizedBox(width: 4),
                      Text(
                        'Supabase Synced',
                        style: AppTheme.englishTextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3ECF8E),
                        ),
                      ),
                    ],
                  ),
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
          const SizedBox(height: 16),

          // 3. Bill Total Breakdown Card (Requirement 3)
          _buildBillTotalBreakdownCard(result, controller),
          const SizedBox(height: 16),

          // 4. Action Buttons: Add to Inventory (Requirement 4) & Sync to Supabase (Requirement 5)
          Row(
            children: [
              // Add to Inventory Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: result.addedToInventory
                        ? AppTheme.accentEmerald.withValues(alpha: 0.2)
                        : AppTheme.accentGold,
                    foregroundColor: result.addedToInventory ? AppTheme.accentEmerald : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: result.addedToInventory ? AppTheme.accentEmerald : Colors.transparent,
                      ),
                    ),
                  ),
                  icon: _isAddingToInventory
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Icon(
                          result.addedToInventory
                              ? Icons.check_circle_rounded
                              : Icons.inventory_2_rounded,
                          size: 20,
                        ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      result.addedToInventory
                          ? 'انوینٹری میں شامل شدہ'
                          : 'انوینٹری میں شامل کریں',
                      style: AppTheme.urduTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: result.addedToInventory ? AppTheme.accentEmerald : Colors.black,
                        height: 1.2,
                      ),
                    ),
                  ),
                  onPressed: (_isAddingToInventory || result.addedToInventory)
                      ? null
                      : () => _handleAddToInventory(result, controller),
                ),
              ),
              const SizedBox(width: 8),

              // Supabase Cloud Sync Button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3ECF8E)),
                    foregroundColor: const Color(0xFF3ECF8E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isSyncingCloud
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3ECF8E)),
                        )
                      : Icon(
                          result.syncedToSupabase
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_upload_rounded,
                          size: 20,
                        ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      result.syncedToSupabase ? 'Supabase Synced' : 'Supabase کلاؤڈ سنک',
                      style: AppTheme.englishTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3ECF8E),
                      ),
                    ),
                  ),
                  onPressed: (_isSyncingCloud || result.syncedToSupabase)
                      ? null
                      : () => _handleSyncToSupabase(result, controller),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Detailed Bill Total Breakdown Card (Requirement 3)
  Widget _buildBillTotalBreakdownCard(OcrScanResult result, OcrScanController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(
        backgroundColor: AppTheme.darkSurface,
        borderColor: AppTheme.accentGold.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_rounded, color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حساب و کل تفصیل بل (Bill Total Breakdown)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.urduTextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGold,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Lines Count
          _TotalRow(
            labelUrdu: 'کل اجناس / اشیاء:',
            labelEn: 'Total Items',
            value: '${result.items.length} اشیاء',
          ),
          const SizedBox(height: 8),

          // Total Weight in kg & Maunds
          _TotalRow(
            labelUrdu: 'کل وزن (کلو و من):',
            labelEn: 'Total Weight',
            value: '${result.totalWeight} kg (${AppFormatters.formatMaunds(result.totalWeight)})',
            valueColor: AppTheme.accentCyan,
          ),
          const SizedBox(height: 8),

          // Subtotal
          _TotalRow(
            labelUrdu: 'میزان خریداری (سب ٹوٹل):',
            labelEn: 'Subtotal',
            value: AppFormatters.formatCurrency(result.subtotal),
          ),
          const SizedBox(height: 8),

          // Mandi Commission / Expenses (Tap to edit)
          InkWell(
            onTap: () => _editCommissionDialog(result, controller),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'آڑھت و دیگر اخراجات:',
                        style: AppTheme.urduTextStyle(fontSize: 12, color: AppTheme.textDarkSecondary),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 12, color: AppTheme.accentGold),
                    ],
                  ),
                ),
                Text(
                  '₨ ${result.commission.toStringAsFixed(0)}',
                  style: AppTheme.englishTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentGold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 10),

          // Grand Bill Total
          Row(
            children: [
              Expanded(
                child: Text(
                  'کل واجب الادا رقم (Grand Total):',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.urduTextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppFormatters.formatCurrency(result.grandTotal),
                    style: AppTheme.englishTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentGold,
                      tabularNumbers: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  // Interactive Biller Date Picker Dialog (Requirement 2)
  Future<void> _pickBillerDate(OcrScanResult result, OcrScanController controller) async {
    AppHaptics.selection();
    final initialDate = result.parsedBillerDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentEmerald,
              surface: AppTheme.darkSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = DateFormat('dd/MM/yyyy').format(picked);
      controller.updateBillerDate(formatted);
      AppHaptics.light();
    }
  }

  // Edit Mandi Commission Dialog
  void _editCommissionDialog(OcrScanResult result, OcrScanController controller) {
    AppHaptics.selection();
    final ctrl = TextEditingController(text: result.commission.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'آڑھت و دیگر اخراجات (Commission / Fee)',
          style: AppTheme.urduTextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: AppTheme.englishTextStyle(fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'رقم (Rs)',
            filled: true,
            fillColor: AppTheme.darkSurfaceElevated,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('منسوخ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0.0;
              controller.updateCommission(val);
              Navigator.pop(ctx);
            },
            child: const Text('محفوظ کریں', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // Action: Add Bill to Inventory (Requirement 4)
  Future<void> _handleAddToInventory(OcrScanResult result, OcrScanController controller) async {
    setState(() => _isAddingToInventory = true);
    AppHaptics.medium();
    try {
      await ref.read(inventoryControllerProvider.notifier).addBillToInventory(result);
      controller.markAddedToInventory();

      // Also update history vault record
      final scans = ref.read(historyControllerProvider).allScans;
      final target = scans.where((s) => s.billNo == result.billNo).firstOrNull;
      if (target != null) {
        await ref.read(historyControllerProvider.notifier).markAddedToInventory(target.id);
      }

      setState(() => _isAddingToInventory = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.accentEmerald,
          content: Text('✓ بل کے تمام اجناس انوینٹری سٹاک میں کامیابی سے شامل ہو گئے!'),
          duration: Duration(milliseconds: 2000),
        ),
      );
    } catch (e) {
      setState(() => _isAddingToInventory = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('انوینٹری میں شامل کرنے میں خرابی: $e')),
      );
    }
  }

  // Action: Sync to Supabase (Requirement 5)
  Future<void> _handleSyncToSupabase(OcrScanResult result, OcrScanController controller) async {
    if (!SupabaseStorageService.isConfigured) {
      showDialog(
        context: context,
        builder: (_) => const SupabaseSettingsDialog(),
      );
      return;
    }

    setState(() => _isSyncingCloud = true);
    AppHaptics.medium();
    try {
      final entry = ScanHistoryEntry.fromScanResult(
        result,
        fullImagePath: widget.croppedImage?.path,
        rawText: result.items.map((i) => i.itemName).join(', '),
      );
      final syncRes = await SupabaseStorageService.syncBillToCloud(
        entry,
        imageFile: widget.croppedImage,
      );

      if (syncRes.success) {
        controller.markSyncedToSupabase(syncRes.imageUrl);
        ref.read(historyControllerProvider.notifier).loadHistory();
      }

      setState(() => _isSyncingCloud = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: syncRes.success ? const Color(0xFF3ECF8E) : AppTheme.errorRed,
          content: Text(syncRes.message),
          duration: const Duration(milliseconds: 2000),
        ),
      );
    } catch (e) {
      setState(() => _isSyncingCloud = false);
    }
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

class _TotalRow extends StatelessWidget {
  final String labelUrdu;
  final String labelEn;
  final String value;
  final Color? valueColor;

  const _TotalRow({
    required this.labelUrdu,
    required this.labelEn,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            labelUrdu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.urduTextStyle(
              fontSize: 13,
              color: AppTheme.textDarkSecondary,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: AppTheme.englishTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textDarkPrimary,
                tabularNumbers: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
