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
        customer: entry.customer,
        items: entry.items,
        totalWeight: entry.totalWeight,
        subtotal: entry.subtotal,
        thumbnailPath: permanentThumbPath,
        imagePath: permanentImagePath,
        createdAt: entry.createdAt,
        rawText: entry.rawText,
        status: entry.status,
      );

      final currentScans = await loadAllScans();
      // Remove any existing duplicate id
      currentScans.removeWhere((s) => s.id == persistentEntry.id);
      currentScans.insert(0, persistentEntry);

      await _writeIndexFile(vaultDir, currentScans);
      return persistentEntry;
    } catch (e) {
      debugPrint('[ScanHistoryService] Failed to save scan: $e');
      rethrow;
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
        // Clean up files
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
  }) {
    final cleanQuery = query.trim().toLowerCase();

    return allScans.where((scan) {
      // 1. Status filter
      if (statusFilter != null && statusFilter != 'All' && scan.status != statusFilter) {
        return false;
      }

      // 2. Query search
      if (cleanQuery.isEmpty) return true;

      // Match customer or billNo
      if (scan.customer.toLowerCase().contains(cleanQuery)) return true;
      if (scan.billNo.toLowerCase().contains(cleanQuery)) return true;
      if (scan.date.toLowerCase().contains(cleanQuery)) return true;

      // Match commodity names
      for (final item in scan.items) {
        if (item.itemName.toLowerCase().contains(cleanQuery)) return true;
      }

      // Match raw extracted text
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

