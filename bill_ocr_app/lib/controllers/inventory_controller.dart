import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_batch_entry.dart';
import '../models/inventory_item.dart';
import '../models/ocr_scan_result.dart';
import '../services/inventory_service.dart';

class InventoryState {
  final bool isLoading;
  final List<InventoryItem> items;
  final List<InventoryItem> filteredItems;
  final List<InventoryBatchEntry> batches;
  final List<InventoryBatchEntry> filteredBatches;
  final String searchQuery;
  final double totalStockValue;
  final double totalStockWeightKg;
  final int totalBillsCount;
  final int selectedViewMode; // 0: By Bill Date (تاریخ بل کے مطابق), 1: Consolidated Stock (مجموعی اسٹاک)
  final String? errorMessage;

  const InventoryState({
    this.isLoading = false,
    this.items = const [],
    this.filteredItems = const [],
    this.batches = const [],
    this.filteredBatches = const [],
    this.searchQuery = '',
    this.totalStockValue = 0.0,
    this.totalStockWeightKg = 0.0,
    this.totalBillsCount = 0,
    this.selectedViewMode = 0,
    this.errorMessage,
  });

  /// Stock in Pakistani Mandi Maunds (من)
  double get totalStockMaunds => totalStockWeightKg / 40.0;

  /// Groups batch entries chronologically by bill date
  Map<String, List<InventoryBatchEntry>> get groupedByBillDate {
    final Map<String, List<InventoryBatchEntry>> map = {};
    for (final batch in filteredBatches) {
      final key = batch.billerDate.isNotEmpty ? batch.billerDate : 'نامعلوم تاریخ';
      map.putIfAbsent(key, () => []).add(batch);
    }
    return map;
  }

  InventoryState copyWith({
    bool? isLoading,
    List<InventoryItem>? items,
    List<InventoryItem>? filteredItems,
    List<InventoryBatchEntry>? batches,
    List<InventoryBatchEntry>? filteredBatches,
    String? searchQuery,
    double? totalStockValue,
    double? totalStockWeightKg,
    int? totalBillsCount,
    int? selectedViewMode,
    String? errorMessage,
  }) {
    return InventoryState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      batches: batches ?? this.batches,
      filteredBatches: filteredBatches ?? this.filteredBatches,
      searchQuery: searchQuery ?? this.searchQuery,
      totalStockValue: totalStockValue ?? this.totalStockValue,
      totalStockWeightKg: totalStockWeightKg ?? this.totalStockWeightKg,
      totalBillsCount: totalBillsCount ?? this.totalBillsCount,
      selectedViewMode: selectedViewMode ?? this.selectedViewMode,
      errorMessage: errorMessage,
    );
  }
}

final inventoryControllerProvider =
    NotifierProvider<InventoryController, InventoryState>(InventoryController.new);

class InventoryController extends Notifier<InventoryState> {
  @override
  InventoryState build() {
    Future.microtask(loadInventory);
    return const InventoryState(isLoading: true);
  }

  Future<void> loadInventory() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await InventoryService.loadInventory();
      final batches = await InventoryService.loadBatches();
      _updateMetrics(items, batches, state.searchQuery);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'انوینٹری لوڈ نہ ہو سکی: $e',
      );
    }
  }

  void setViewMode(int modeIndex) {
    state = state.copyWith(selectedViewMode: modeIndex);
  }

  void onSearchChanged(String query) {
    _updateMetrics(state.items, state.batches, query);
  }

  Future<void> addBillToInventory(OcrScanResult bill) async {
    state = state.copyWith(isLoading: true);
    try {
      final updatedList = await InventoryService.addBillToInventory(bill);
      final updatedBatches = await InventoryService.loadBatches();
      _updateMetrics(updatedList, updatedBatches, state.searchQuery);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'بل انوینٹری میں شامل نہ ہو سکا: $e',
      );
    }
  }

  Future<File?> exportInventoryExcel() async {
    try {
      return await InventoryService.generateInventoryExcel(state.items, state.batches);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Excel برآمد میں خرابی: $e');
      return null;
    }
  }

  void _updateMetrics(List<InventoryItem> items, List<InventoryBatchEntry> batches, String query) {
    double totalVal = 0;
    double totalWt = 0;
    final Set<String> distinctBills = {};

    for (final item in items) {
      totalVal += item.totalStockValue;
      totalWt += item.stockWeightKg;
      if (item.lastBillNo.isNotEmpty && item.lastBillNo != 'N/A') {
        distinctBills.add(item.lastBillNo);
      }
    }
    for (final b in batches) {
      if (b.billNo.isNotEmpty && b.billNo != 'N/A') {
        distinctBills.add(b.billNo);
      }
    }

    final clean = query.trim().toLowerCase();

    // Filter consolidated items
    final filteredItems = items.where((item) {
      if (clean.isEmpty) return true;
      return item.commodityName.toLowerCase().contains(clean) ||
          item.englishName.toLowerCase().contains(clean) ||
          item.lastSupplier.toLowerCase().contains(clean) ||
          item.lastBillerDate.toLowerCase().contains(clean) ||
          item.lastBillNo.toLowerCase().contains(clean);
    }).toList();

    // Filter separate bill date batches
    final filteredBatches = batches.where((b) {
      if (clean.isEmpty) return true;
      return b.commodityName.toLowerCase().contains(clean) ||
          b.englishName.toLowerCase().contains(clean) ||
          b.customer.toLowerCase().contains(clean) ||
          b.billNo.toLowerCase().contains(clean) ||
          b.billerDate.toLowerCase().contains(clean);
    }).toList();

    state = state.copyWith(
      isLoading: false,
      items: items,
      filteredItems: filteredItems,
      batches: batches,
      filteredBatches: filteredBatches,
      searchQuery: query,
      totalStockValue: totalVal,
      totalStockWeightKg: totalWt,
      totalBillsCount: distinctBills.length,
      errorMessage: null,
    );
  }
}
