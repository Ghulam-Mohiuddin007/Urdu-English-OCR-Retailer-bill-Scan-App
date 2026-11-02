import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/supabase_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/inventory_batch_entry.dart';
import '../../models/inventory_item.dart';
import '../../services/excel_export_service.dart';
import '../settings/supabase_settings_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(inventoryControllerProvider);
    final invCtrl = ref.read(inventoryControllerProvider.notifier);
    final supaState = ref.watch(supabaseControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkCanvas,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'انوینٹری اسٹاک رجسٹر',
              style: AppTheme.urduTextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            Text(
              'Mandi Inventory & Date-wise Ledger',
              style: AppTheme.englishTextStyle(
                fontSize: 11,
                color: AppTheme.textDarkMuted,
              ),
            ),
          ],
        ),
        actions: [
          // Supabase Cloud Status Indicator / Settings
          IconButton(
            icon: Icon(
              supaState.isConnected ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
              color: supaState.isConnected ? AppTheme.accentEmerald : AppTheme.textDarkMuted,
            ),
            tooltip: 'Supabase سیٹنگز',
            onPressed: () {
              AppHaptics.light();
              showDialog(
                context: context,
                builder: (_) => const SupabaseSettingsDialog(),
              );
            },
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentEmerald),
            tooltip: 'تازہ کریں (Refresh)',
            onPressed: () {
              AppHaptics.light();
              invCtrl.loadInventory();
            },
          ),
        ],
      ),
      body: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // 1. Total Inventory Summary Cards (Zero overflow responsive row)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      title: 'کل مالیت سٹاک',
                      value: AppFormatters.formatCompactCurrency(invState.totalStockValue),
                      color: AppTheme.accentEmerald,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMetric(
                      title: 'کل وزن (من)',
                      value: AppFormatters.formatMaunds(invState.totalStockWeightKg),
                      color: AppTheme.accentGold,
                      icon: Icons.scale_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMetric(
                      title: 'اجناس کی اقسام',
                      value: '${invState.items.length}',
                      color: AppTheme.accentCyan,
                      icon: Icons.inventory_2_rounded,
                    ),
                  ),
                ],
              ),
            ),

            // 2. View Mode Switcher: "By Bill Date" vs "Consolidated Stock"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeSwitchButton(
                        labelUrdu: 'بل کی تاریخ کے مطابق',
                        labelEn: 'By Bill Date',
                        icon: Icons.calendar_month_rounded,
                        isSelected: invState.selectedViewMode == 0,
                        onTap: () {
                          AppHaptics.selection();
                          invCtrl.setViewMode(0);
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ModeSwitchButton(
                        labelUrdu: 'مجموعی اسٹاک',
                        labelEn: 'Consolidated Stock',
                        icon: Icons.layers_rounded,
                        isSelected: invState.selectedViewMode == 1,
                        onTap: () {
                          AppHaptics.selection();
                          invCtrl.setViewMode(1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Search Bar with Export Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: invCtrl.onSearchChanged,
                      style: AppTheme.englishTextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'تلاش کریں (Search commodity, date, bill #)...',
                        hintStyle: AppTheme.englishTextStyle(
                          fontSize: 13,
                          color: AppTheme.textDarkMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.textDarkSecondary,
                          size: 20,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  invCtrl.onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.darkSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export Inventory to Excel Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.file_download_rounded, size: 18),
                    label: Text(
                      'ایکسل',
                      style: AppTheme.urduTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    onPressed: () async {
                      AppHaptics.medium();
                      final file = await invCtrl.exportInventoryExcel();
                      if (file != null) {
                        await ExcelExportService.openExcelFile(file);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 4. Main Body: Date-wise Breakdown or Consolidated Stock
            Expanded(
              child: invState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accentEmerald),
                    )
                  : invState.selectedViewMode == 0
                      ? _buildDateWiseInventoryView(invState)
                      : _buildConsolidatedInventoryView(invState),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Date-Wise Separate Inventory View (Requirement: "Show Totel inventory with seperate data accordingto added dae of bill")
  Widget _buildDateWiseInventoryView(InventoryState invState) {
    final grouped = invState.groupedByBillDate;

    if (grouped.isEmpty) {
      return _buildEmptyInventory(
        message: 'اس تاریخ کے مطابق کوئی انوینٹری ڈیٹا موجود نہیں',
      );
    }

    final dates = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final dateKey = dates[index];
        final batchesForDate = grouped[dateKey]!;

        double dateWeight = 0;
        double dateVal = 0;
        for (final b in batchesForDate) {
          dateWeight += b.weightKg;
          dateVal += b.totalPrice;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Group Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceElevated,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تاریخ رسید: $dateKey',
                            style: AppTheme.englishTextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                          Text(
                            'شامل شدہ اشیاء: ${batchesForDate.length} آئٹمز',
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
                          AppFormatters.formatCurrency(dateVal),
                          style: AppTheme.englishTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentGold,
                            tabularNumbers: true,
                          ),
                        ),
                        Text(
                          '${dateWeight.toStringAsFixed(0)} kg (${AppFormatters.formatMaunds(dateWeight)})',
                          style: AppTheme.englishTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Itemized Batch Cards under this Date
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: batchesForDate.map((batch) {
                    return _DateBatchItemCard(batch: batch);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 2. Consolidated Stock View
  Widget _buildConsolidatedInventoryView(InventoryState invState) {
    if (invState.filteredItems.isEmpty) {
      return _buildEmptyInventory(
        message: 'انوینٹری میں کوئی جنس موجود نہیں',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: invState.filteredItems.length,
      itemBuilder: (context, index) {
        final item = invState.filteredItems[index];
        return _InventoryCommodityCard(item: item);
      },
    );
  }

  Widget _buildEmptyInventory({required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 44,
              color: AppTheme.textDarkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.urduTextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDarkSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اسکین اسکرین سے بل اسکین کر کے انوینٹری میں شامل کریں',
            style: AppTheme.urduTextStyle(
              fontSize: 12,
              color: AppTheme.textDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchButton extends StatelessWidget {
  final String labelUrdu;
  final String labelEn;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeSwitchButton({
    required this.labelUrdu,
    required this.labelEn,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.black : AppTheme.textDarkMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                labelUrdu,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.urduTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : AppTheme.textDarkSecondary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryMetric({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: AppTheme.glassCardDecoration(
        backgroundColor: AppTheme.darkSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.urduTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDarkSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTheme.englishTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDarkPrimary,
                tabularNumbers: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Item card for date-wise separate breakdown (Requirement: "seperate data accordingto added dae of bill")
class _DateBatchItemCard extends StatelessWidget {
  final InventoryBatchEntry batch;

  const _DateBatchItemCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Commodity Name, Bill # badge, and Line Total
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        batch.commodityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.urduTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDarkPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${batch.billNo}',
                        style: AppTheme.englishTextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppFormatters.formatCurrency(batch.totalPrice),
                style: AppTheme.englishTextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentGold,
                  tabularNumbers: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Bottom Stats Row: Supplier, Weight in kg/maunds, Rate per Maund
          Row(
            children: [
              // Supplier
              Expanded(
                flex: 3,
                child: Text(
                  'سپلائر: ${batch.customer}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.urduTextStyle(
                    fontSize: 11,
                    color: AppTheme.textDarkMuted,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Weight
              Flexible(
                flex: 3,
                child: Text(
                  '${batch.weightKg} kg (${AppFormatters.formatMaunds(batch.weightKg)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTheme.englishTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Rate / 40kg
              Flexible(
                flex: 2,
                child: Text(
                  '@ ₨${batch.unitPrice.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTheme.englishTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDarkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryCommodityCard extends StatelessWidget {
  final InventoryItem item;

  const _InventoryCommodityCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration(
        backgroundColor: AppTheme.darkSurface.withValues(alpha: 0.95),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Commodity Name & Total Worth
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.grain_rounded,
                  color: AppTheme.accentEmerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.commodityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.urduTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDarkPrimary,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      'کل آمد: ${item.totalBillsCount} بلز • آخری سپلائر: ${item.lastSupplier}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.urduTextStyle(
                        fontSize: 11,
                        color: AppTheme.textDarkMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatCurrency(item.totalStockValue),
                    style: AppTheme.englishTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentGold,
                      tabularNumbers: true,
                    ),
                  ),
                  Text(
                    'کل مالیت (Worth)',
                    style: AppTheme.englishTextStyle(
                      fontSize: 10,
                      color: AppTheme.textDarkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 10),

          // Bottom Stats Row: Weight in kg, Maunds, Rate, Last Biller Date (Wrap / Flexible defended)
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'موجودہ وزن',
                  value: '${item.stockWeightKg} kg (${AppFormatters.formatMaunds(item.stockWeightKg)})',
                  color: AppTheme.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'آخری ریٹ / 40 کلو',
                  value: '₨ ${item.lastPurchaseRate.toStringAsFixed(0)}',
                  color: AppTheme.textDarkPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'تاریخ رسید',
                  value: item.lastBillerDate,
                  color: AppTheme.textDarkSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.urduTextStyle(
            fontSize: 10,
            color: AppTheme.textDarkMuted,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: AppTheme.englishTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              tabularNumbers: true,
            ),
          ),
        ),
      ],
    );
  }
}
