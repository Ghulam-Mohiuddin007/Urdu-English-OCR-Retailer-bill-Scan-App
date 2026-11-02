import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_history_entry.dart';
import '../services/scan_history_service.dart';
import '../services/supabase_storage_service.dart';

class HistoryState {
  final bool isLoading;
  final bool isSyncingCloud;
  final List<ScanHistoryEntry> allScans;
  final List<ScanHistoryEntry> filteredScans;
  final String searchQuery;
  final String activeStatusFilter;
  final String activeDateFilter;
  final String? errorMessage;
  final String? syncStatusMessage;

  const HistoryState({
    this.isLoading = false,
    this.isSyncingCloud = false,
    this.allScans = const [],
    this.filteredScans = const [],
    this.searchQuery = '',
    this.activeStatusFilter = 'All',
    this.activeDateFilter = 'All',
    this.errorMessage,
    this.syncStatusMessage,
  });

  /// Count of bills pending cloud backup
  int get pendingCloudCount => allScans.where((s) => !s.syncedToSupabase).length;

  /// Count of bills added to inventory
  int get inventoryAddedCount => allScans.where((s) => s.addedToInventory).length;

  HistoryState copyWith({
    bool? isLoading,
    bool? isSyncingCloud,
    List<ScanHistoryEntry>? allScans,
    List<ScanHistoryEntry>? filteredScans,
    String? searchQuery,
    String? activeStatusFilter,
    String? activeDateFilter,
    String? errorMessage,
    String? syncStatusMessage,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      isSyncingCloud: isSyncingCloud ?? this.isSyncingCloud,
      allScans: allScans ?? this.allScans,
      filteredScans: filteredScans ?? this.filteredScans,
      searchQuery: searchQuery ?? this.searchQuery,
      activeStatusFilter: activeStatusFilter ?? this.activeStatusFilter,
      activeDateFilter: activeDateFilter ?? this.activeDateFilter,
      errorMessage: errorMessage,
      syncStatusMessage: syncStatusMessage,
    );
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);

class HistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    Future.microtask(loadHistory);
    return const HistoryState(isLoading: true);
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final scans = await ScanHistoryService.loadAllScans();
      final filtered = ScanHistoryService.filterScans(
        allScans: scans,
        query: state.searchQuery,
        statusFilter: state.activeStatusFilter,
        dateFilter: state.activeDateFilter,
      );
      state = state.copyWith(
        isLoading: false,
        allScans: scans,
        filteredScans: filtered,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تاریخچہ لوڈ نہ ہو سکا: $e',
      );
    }
  }

  void onSearchChanged(String query) {
    final filtered = ScanHistoryService.filterScans(
      allScans: state.allScans,
      query: query,
      statusFilter: state.activeStatusFilter,
      dateFilter: state.activeDateFilter,
    );
    state = state.copyWith(
      searchQuery: query,
      filteredScans: filtered,
    );
  }

  void onFilterChanged(String status) {
    final filtered = ScanHistoryService.filterScans(
      allScans: state.allScans,
      query: state.searchQuery,
      statusFilter: status,
      dateFilter: state.activeDateFilter,
    );
    state = state.copyWith(
      activeStatusFilter: status,
      filteredScans: filtered,
    );
  }

  void onDateFilterChanged(String dateFilter) {
    final filtered = ScanHistoryService.filterScans(
      allScans: state.allScans,
      query: state.searchQuery,
      statusFilter: state.activeStatusFilter,
      dateFilter: dateFilter,
    );
    state = state.copyWith(
      activeDateFilter: dateFilter,
      filteredScans: filtered,
    );
  }

  Future<void> markAddedToInventory(String billId) async {
    final currentScans = List<ScanHistoryEntry>.from(state.allScans);
    final idx = currentScans.indexWhere((s) => s.id == billId);
    if (idx != -1) {
      final updated = currentScans[idx].copyWith(addedToInventory: true);
      await ScanHistoryService.updateScan(updated);
      await loadHistory();
    }
  }

  /// Syncs all un-synced bills to Supabase cloud storage
  Future<void> syncAllPendingToCloud() async {
    if (!SupabaseStorageService.isConfigured) {
      state = state.copyWith(
        syncStatusMessage: 'Supabase پہلے تشکیل دیں (Configure Supabase in settings)',
      );
      return;
    }

    state = state.copyWith(isSyncingCloud: true, syncStatusMessage: 'کلاؤڈ سنک ہو رہا ہے...');

    int successCount = 0;
    try {
      for (final scan in state.allScans) {
        if (!scan.syncedToSupabase) {
          final file = scan.imagePath != null ? File(scan.imagePath!) : null;
          final result = await SupabaseStorageService.syncBillToCloud(scan, imageFile: file);
          if (result.success) {
            final updated = scan.copyWith(
              syncedToSupabase: true,
              supabaseImageUrl: result.imageUrl,
            );
            await ScanHistoryService.updateScan(updated);
            successCount++;
          }
        }
      }

      await loadHistory();
      state = state.copyWith(
        isSyncingCloud: false,
        syncStatusMessage: '$successCount بلز Supabase پر بیک اپ ہو گئے (Synced to Cloud)',
      );
    } catch (e) {
      state = state.copyWith(
        isSyncingCloud: false,
        syncStatusMessage: 'سنک میں خرابی پیش آگئی: $e',
      );
    }
  }

  Future<void> deleteScan(String id) async {
    await ScanHistoryService.deleteScan(id);
    await loadHistory();
  }
}
