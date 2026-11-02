import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/history_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/supabase_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/scan_history_entry.dart';
import '../../services/excel_export_service.dart';
import '../result/ocr_result_table_screen.dart';
import '../settings/supabase_settings_dialog.dart';

class ScanHistoryScreen extends ConsumerStatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  ConsumerState<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends ConsumerState<ScanHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyControllerProvider);
    final historyController = ref.read(historyControllerProvider.notifier);
    final supaState = ref.watch(supabaseControllerProvider);

    // Compute summary metrics
    double grandTotalRevenue = 0;
    double grandTotalWeight = 0;
    for (final scan in historyState.allScans) {
      grandTotalRevenue += scan.grandTotal;
      grandTotalWeight += scan.totalWeight;
    }

    return Scaffold(
      backgroundColor: AppTheme.darkCanvas,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'محفوظ شدہ رسیدیں (Bill History)',
              style: AppTheme.urduTextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDarkPrimary,
                height: 1.3,
              ),
            ),
            Text(
              'Archive, Cloud Sync & Inventory Ledger',
              style: AppTheme.englishTextStyle(
                fontSize: 11,
                color: AppTheme.textDarkMuted,
              ),
            ),
          ],
        ),
        actions: [
          // Supabase Settings Shortcut
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentEmerald),
            tooltip: 'تازہ کریں (Refresh)',
            onPressed: () {
              AppHaptics.light();
              historyController.loadHistory();
            },
          ),
        ],
      ),
      body: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // 1. Metric Overview Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _MetricCard(
                    title: 'کل رسیدیں',
                    value: '${historyState.allScans.length}',
                    color: AppTheme.accentCyan,
                    icon: Icons.receipt_long_rounded,
                  ),
                  const SizedBox(width: 8),
                  _MetricCard(
                    title: 'کل وزن (من)',
                    value: AppFormatters.formatMaunds(grandTotalWeight),
                    color: AppTheme.accentGold,
                    icon: Icons.scale_rounded,
                  ),
                  const SizedBox(width: 8),
                  _MetricCard(
                    title: 'کل رقم بلز',
                    value: AppFormatters.formatCompactCurrency(grandTotalRevenue),
                    color: AppTheme.accentEmerald,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ],
              ),
            ),

            // 2. Search & Cloud Sync Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: historyController.onSearchChanged,
                      style: AppTheme.englishTextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'تلاش کریں (Search customer, item, bill #)...',
                        hintStyle: AppTheme.englishTextStyle(
                          fontSize: 13,
                          color: AppTheme.textDarkMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.textDarkSecondary,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  historyController.onSearchChanged('');
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

                  // Sync All Pending to Supabase Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3ECF8E),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: historyState.isSyncingCloud
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 16),
                    label: Text(
                      historyState.pendingCloudCount > 0
                          ? '${historyState.pendingCloudCount} سنک'
                          : 'کلاؤڈ',
                      style: AppTheme.englishTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: historyState.isSyncingCloud
                        ? null
                        : () => historyController.syncAllPendingToCloud(),
                  ),
                ],
              ),
            ),

            // Sync Status Notification Banner if any
            if (historyState.syncStatusMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.accentEmerald),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        historyState.syncStatusMessage!,
                        style: AppTheme.englishTextStyle(fontSize: 11, color: AppTheme.accentEmerald),
                      ),
                    ),
                  ],
                ),
              ),

            // 3. Date & Category Filter Chips (Requirement 1 & 2)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'تمام تاریخیں (All Time)',
                    isSelected: historyState.activeDateFilter == 'All',
                    onTap: () => historyController.onDateFilterChanged('All'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'آج (Today)',
                    isSelected: historyState.activeDateFilter == 'Today',
                    onTap: () => historyController.onDateFilterChanged('Today'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'اس ہفتے (This Week)',
                    isSelected: historyState.activeDateFilter == 'This Week',
                    onTap: () => historyController.onDateFilterChanged('This Week'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'انوینٹری سٹاک (Inventory)',
                    isSelected: historyState.activeStatusFilter == 'Inventory',
                    onTap: () => historyController.onFilterChanged(
                      historyState.activeStatusFilter == 'Inventory' ? 'All' : 'Inventory',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 4. Archive Entries List
            Expanded(
              child: historyState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accentEmerald),
                    )
                  : historyState.filteredScans.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: historyState.filteredScans.length,
                          itemBuilder: (context, index) {
                            final entry = historyState.filteredScans[index];
                            return _ScanArchiveCard(
                              entry: entry,
                              onTap: () => _openBillDetailsModal(entry),
                              onDelete: () => _confirmDelete(entry.id),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.receipt_long_rounded,
              size: 48,
              color: AppTheme.textDarkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'کوئی محفوظ رسید نہیں ملی',
            style: AppTheme.urduTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDarkSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'نئی رسید اسکین کر کے یہاں خودکار محفوظ ہوگی',
            style: AppTheme.urduTextStyle(
              fontSize: 13,
              color: AppTheme.textDarkMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _openBillDetailsModal(ScanHistoryEntry entry) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_rounded, color: AppTheme.accentEmerald, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بل #${entry.billNo} • ${entry.billerDate}',
                            style: AppTheme.englishTextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            entry.customer,
                            style: AppTheme.urduTextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Grand Total Highlights
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('کل رقم (Grand Total)', style: AppTheme.urduTextStyle(fontSize: 11, color: AppTheme.textDarkMuted)),
                          Text(
                            AppFormatters.formatCurrency(entry.grandTotal),
                            style: AppTheme.englishTextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.accentGold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('کل وزن', style: AppTheme.urduTextStyle(fontSize: 11, color: AppTheme.textDarkMuted)),
                          Text(
                            '${entry.totalWeight} kg (${AppFormatters.formatMaunds(entry.totalWeight)})',
                            style: AppTheme.englishTextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Itemized List
                Text('تفصیل اشیاء (Itemized Lines):', style: AppTheme.urduTextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...entry.items.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.urduTextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${item.weight} kg @ ₨${item.unitPrice.toStringAsFixed(0)} = ₨${item.totalPrice.toStringAsFixed(0)}',
                              maxLines: 1,
                              style: AppTheme.englishTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDarkSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Modal Actions
                Row(
                  children: [
                    // Open in Full Review / Editor
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: Text(
                          'ترمیم و مکمل جائزہ',
                          style: AppTheme.urduTextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, height: 1.2),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OcrResultTableScreen(
                                initialResult: entry.toScanResult(),
                                croppedImage: entry.imagePath != null ? File(entry.imagePath!) : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Add to Inventory action
                    if (!entry.addedToInventory)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.inventory_2_rounded, size: 16),
                        label: const Text('انوینٹری'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(inventoryControllerProvider.notifier).addBillToInventory(entry.toScanResult());
                          await ref.read(historyControllerProvider.notifier).markAddedToInventory(entry.id);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String id) {
    AppHaptics.medium();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'رسید حذف کریں؟',
          style: AppTheme.urduTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'کیا آپ واقعی اس رسید کا ریکارڈ لوکل سٹوریج سے مستقل حذف کرنا چاہتے ہیں؟',
          style: AppTheme.urduTextStyle(fontSize: 14, color: AppTheme.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'منسوخ (Cancel)',
              style: AppTheme.englishTextStyle(color: AppTheme.textDarkMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(historyControllerProvider.notifier).deleteScan(id);
            },
            child: Text(
              'حذف کریں (Delete)',
              style: AppTheme.urduTextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentEmerald
              : AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentEmerald
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppTheme.englishTextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : AppTheme.textDarkSecondary,
          ),
        ),
      ),
    );
  }
}

class _ScanArchiveCard extends StatelessWidget {
  final ScanHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScanArchiveCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final thumbFile = entry.thumbnailPath != null ? File(entry.thumbnailPath!) : null;
    final hasThumb = thumbFile != null && thumbFile.existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCardDecoration(
        backgroundColor: AppTheme.darkSurface.withValues(alpha: 0.95),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 1. Thumbnail Image with rounded corners
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: hasThumb
                      ? Image.file(
                          thumbFile,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Metadata Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'بل #${entry.billNo}',
                          style: AppTheme.englishTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentEmerald,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تاریخ: ${entry.billerDate}',
                          style: AppTheme.englishTextStyle(
                            fontSize: 11,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.urduTextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDarkPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${entry.items.length} اشیاء • ${entry.totalWeight} کلو (${AppFormatters.formatMaunds(entry.totalWeight)})',
                          style: AppTheme.englishTextStyle(
                            fontSize: 11,
                            color: AppTheme.textDarkSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (entry.addedToInventory)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.inventory_2_rounded, size: 13, color: AppTheme.accentGold),
                          ),
                        if (entry.syncedToSupabase)
                          const Icon(Icons.cloud_done_rounded, size: 13, color: Color(0xFF3ECF8E)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // 3. Total & Action Menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.formatCurrency(entry.grandTotal),
                    style: AppTheme.englishTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentGold,
                      tabularNumbers: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.file_download_outlined,
                          size: 18,
                          color: AppTheme.accentEmerald,
                        ),
                        tooltip: 'Excel برآمد کریں',
                        onPressed: () async {
                          AppHaptics.light();
                          final file = await ExcelExportService.generateExcel(
                            result: entry.toScanResult(),
                          );
                          await ExcelExportService.openExcelFile(file);
                        },
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppTheme.errorRed,
                        ),
                        tooltip: 'حذف کریں',
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppTheme.darkSurfaceElevated,
      child: const Center(
        child: Icon(
          Icons.receipt_rounded,
          color: AppTheme.textDarkMuted,
          size: 26,
        ),
      ),
    );
  }
}
