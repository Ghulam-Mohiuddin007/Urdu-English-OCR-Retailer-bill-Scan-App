import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_history_entry.dart';
import '../services/scan_history_service.dart';

class HistoryState {
  final bool isLoading;
  final List<ScanHistoryEntry> allScans;
  final List<ScanHistoryEntry> filteredScans;
  final String searchQuery;
  final String activeStatusFilter;
  final String? errorMessage;

  const HistoryState({
    this.isLoading = false,
    this.allScans = const [],
    this.filteredScans = const [],
    this.searchQuery = '',
    this.activeStatusFilter = 'All',
    this.errorMessage,
  });

  HistoryState copyWith({
    bool? isLoading,
    List<ScanHistoryEntry>? allScans,
    List<ScanHistoryEntry>? filteredScans,
    String? searchQuery,
    String? activeStatusFilter,
    String? errorMessage,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      allScans: allScans ?? this.allScans,
      filteredScans: filteredScans ?? this.filteredScans,
      searchQuery: searchQuery ?? this.searchQuery,
      activeStatusFilter: activeStatusFilter ?? this.activeStatusFilter,
      errorMessage: errorMessage,
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
    );
    state = state.copyWith(
      activeStatusFilter: status,
      filteredScans: filtered,
    );
  }

  Future<void> deleteScan(String id) async {
    await ScanHistoryService.deleteScan(id);
    await loadHistory();
  }
}
