import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/scan_history_entry.dart';

class ScanHistoryService {
  static const String _vaultFolder = 'scan_vault';
  static const String _indexFileName = 'vault_index.json';

  /// Resolves the dedicated local storage directory for scan archive.
  static Future<Directory> _getVaultDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${docsDir.path}/$_vaultFolder');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Loads all saved scan entries sorted by newest first.
  static Future<List<ScanHistoryEntry>> loadAllScans() async {
    try {
      final vaultDir = await _getVaultDirectory();
      final indexFile = File('${vaultDir.path}/$_indexFileName');

      if (!await indexFile.exists()) {
        return [];
      }

      final jsonContent = await indexFile.readAsString();
      if (jsonContent.trim().isEmpty) return [];

      final dynamic decoded = json.decode(jsonContent);
      if (decoded is List) {
        final List<ScanHistoryEntry> entries = decoded
            .map((item) => ScanHistoryEntry.fromMap(item as Map<String, dynamic>))
            .toList();

        // Sort descending by creation date
        entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return entries;
      }
      return [];
    } catch (e) {
      debugPrint('[ScanHistoryService] Error loading scans: $e');
      return [];
    }
  }

  /// Persists a new scan result with permanent local file archiving.
  static Future<ScanHistoryEntry> saveScan(
    ScanHistoryEntry entry, {
    File? originalFile,
    File? thumbnailFile,
  }) async {
    try {
      final vaultDir = await _getVaultDirectory();
      final id = entry.id;

      String? permanentImagePath = entry.imagePath;
      String? permanentThumbPath = entry.thumbnailPath;

      // Copy image to persistent vault if provided
      if (originalFile != null && await originalFile.exists()) {
        final ext = originalFile.path.split('.').last;
        final target = File('${vaultDir.path}/img_$id.$ext');
        await originalFile.copy(target.path);
        permanentImagePath = target.path;
      }

      // Copy thumbnail to persistent vault
      if (thumbnailFile != null && await thumbnailFile.exists()) {
        final target = File('${vaultDir.path}/thumb_$id.jpg');
        await thumbnailFile.copy(target.path);
        permanentThumbPath = target.path;
      }

      final persistentEntry = ScanHistoryEntry(
        id: entry.id,
        billNo: entry.billNo,
        date: entry.date,
        billerDate: entry.billerDate,
        customer: entry.customer,
        items: entry.items,
        totalWeight: entry.totalWeight,
        subtotal: entry.subtotal,
        commission: entry.commission,
        grandTotal: entry.grandTotal,
        addedToInventory: entry.addedToInventory,
        syncedToSupabase: entry.syncedToSupabase,
        supabaseId: entry.supabaseId,
        supabaseImageUrl: entry.supabaseImageUrl,
        thumbnailPath: permanentThumbPath,
        imagePath: permanentImagePath,
        createdAt: entry.createdAt,
        rawText: entry.rawText,
        status: entry.status,
      );

      final currentScans = await loadAllScans();
      currentScans.removeWhere((s) => s.id == persistentEntry.id);
      currentScans.insert(0, persistentEntry);

      await _writeIndexFile(vaultDir, currentScans);
      return persistentEntry;
    } catch (e) {
      debugPrint('[ScanHistoryService] Failed to save scan: $e');
      rethrow;
    }
  }

  /// Updates an existing scan record (e.g. mark added to inventory or cloud synced)
  static Future<void> updateScan(ScanHistoryEntry updated) async {
    try {
      final vaultDir = await _getVaultDirectory();
      final currentScans = await loadAllScans();
      final idx = currentScans.indexWhere((s) => s.id == updated.id);
      if (idx != -1) {
        currentScans[idx] = updated;
        await _writeIndexFile(vaultDir, currentScans);
      }
    } catch (e) {
      debugPrint('[ScanHistoryService] Error updating scan: $e');
    }
  }

  /// Deletes a scan and cleans up associated images from disk.
  static Future<void> deleteScan(String id) async {
    try {
      final vaultDir = await _getVaultDirectory();
      final currentScans = await loadAllScans();

      final targetIndex = currentScans.indexWhere((s) => s.id == id);
      if (targetIndex != -1) {
        final target = currentScans[targetIndex];
        if (target.imagePath != null) {
          final imgFile = File(target.imagePath!);
          if (await imgFile.exists()) await imgFile.delete();
        }
        if (target.thumbnailPath != null) {
          final thumbFile = File(target.thumbnailPath!);
          if (await thumbFile.exists()) await thumbFile.delete();
        }

        currentScans.removeAt(targetIndex);
        await _writeIndexFile(vaultDir, currentScans);
      }
    } catch (e) {
      debugPrint('[ScanHistoryService] Failed to delete scan: $e');
    }
  }

  /// Searches scans by query string across customer, bill#, commodity names, or dates.
  static List<ScanHistoryEntry> filterScans({
    required List<ScanHistoryEntry> allScans,
    required String query,
    String? statusFilter,
    String? dateFilter, // 'All', 'Today', 'This Week', 'This Month'
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final now = DateTime.now();

    return allScans.where((scan) {
      // 1. Status filter
      if (statusFilter != null && statusFilter != 'All') {
        if (statusFilter == 'Inventory' && !scan.addedToInventory) return false;
        if (statusFilter == 'Cloud' && !scan.syncedToSupabase) return false;
        if (statusFilter == 'Saved' && scan.status != 'Saved') return false;
      }

      // 2. Date Filter
      if (dateFilter != null && dateFilter != 'All') {
        final diff = now.difference(scan.createdAt);
        if (dateFilter == 'Today' && diff.inDays > 0) return false;
        if (dateFilter == 'This Week' && diff.inDays > 7) return false;
        if (dateFilter == 'This Month' && diff.inDays > 30) return false;
      }

      // 3. Query search
      if (cleanQuery.isEmpty) return true;

      if (scan.customer.toLowerCase().contains(cleanQuery)) return true;
      if (scan.billNo.toLowerCase().contains(cleanQuery)) return true;
      if (scan.billerDate.toLowerCase().contains(cleanQuery)) return true;
      if (scan.date.toLowerCase().contains(cleanQuery)) return true;

      for (final item in scan.items) {
        if (item.itemName.toLowerCase().contains(cleanQuery)) return true;
      }

      if (scan.rawText != null && scan.rawText!.toLowerCase().contains(cleanQuery)) {
        return true;
      }

      return false;
    }).toList();
  }

  static Future<void> _writeIndexFile(
    Directory vaultDir,
    List<ScanHistoryEntry> scans,
  ) async {
    final indexFile = File('${vaultDir.path}/$_indexFileName');
    final jsonString = json.encode(scans.map((s) => s.toMap()).toList());
    await indexFile.writeAsString(jsonString, flush: true);
  }
}
