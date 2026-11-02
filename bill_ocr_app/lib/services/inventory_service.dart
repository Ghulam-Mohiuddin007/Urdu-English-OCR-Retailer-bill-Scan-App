import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/inventory_batch_entry.dart';
import '../models/inventory_item.dart';
import '../models/ocr_scan_result.dart';
import 'supabase_storage_service.dart';

class InventoryService {
  static const String _folderName = 'inventory';
  static const String _fileName = 'inventory_ledger.json';
  static const String _batchesFileName = 'inventory_batches.json';

  static Future<Directory> _getInventoryDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all current inventory items from local JSON ledger
  static Future<List<InventoryItem>> loadInventory() async {
    try {
      final dir = await _getInventoryDirectory();
      final file = File('${dir.path}/$_fileName');
      if (!await file.exists()) {
        return _getDefaultInitialInventory();
      }

      final jsonContent = await file.readAsString();
      if (jsonContent.trim().isEmpty) return _getDefaultInitialInventory();

      final dynamic decoded = json.decode(jsonContent);
      if (decoded is List) {
        final items = decoded
            .map((item) => InventoryItem.fromMap(item as Map<String, dynamic>))
            .toList();
        // Sort descending by total stock value
        items.sort((a, b) => b.totalStockValue.compareTo(a.totalStockValue));
        return items;
      }
      return _getDefaultInitialInventory();
    } catch (e) {
      debugPrint('[InventoryService] Error loading inventory: $e');
      return _getDefaultInitialInventory();
    }
  }

  /// Loads all separate inventory batch records entered from past bills
  static Future<List<InventoryBatchEntry>> loadBatches() async {
    try {
      final dir = await _getInventoryDirectory();
      final file = File('${dir.path}/$_batchesFileName');
      if (!await file.exists()) {
        final initialBatches = _getDefaultInitialBatches();
        await _saveBatches(initialBatches);
        return initialBatches;
      }

      final jsonContent = await file.readAsString();
      if (jsonContent.trim().isEmpty) {
        final initialBatches = _getDefaultInitialBatches();
        await _saveBatches(initialBatches);
        return initialBatches;
      }

      final dynamic decoded = json.decode(jsonContent);
      if (decoded is List) {
        final batches = decoded
            .map((b) => InventoryBatchEntry.fromMap(b as Map<String, dynamic>))
            .toList();
        // Sort newest first
        batches.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        return batches;
      }
      return _getDefaultInitialBatches();
    } catch (e) {
      debugPrint('[InventoryService] Error loading batches: $e');
      return _getDefaultInitialBatches();
    }
  }

  static Future<void> _saveBatches(List<InventoryBatchEntry> batches) async {
    final dir = await _getInventoryDirectory();
    final file = File('${dir.path}/$_batchesFileName');
    final jsonStr = json.encode(batches.map((b) => b.toMap()).toList());
    await file.writeAsString(jsonStr, flush: true);
  }

  /// Adds a bill's line items directly into the inventory (both consolidated & separate by bill date)
  static Future<List<InventoryItem>> addBillToInventory(OcrScanResult bill) async {
    try {
      final currentStock = await loadInventory();
      final currentBatches = await loadBatches();
      final dir = await _getInventoryDirectory();
      final now = DateTime.now();

      // 1. Record itemized batches by bill date
      for (int i = 0; i < bill.items.length; i++) {
        final item = bill.items[i];
        final batchEntry = InventoryBatchEntry(
          id: 'batch_${bill.billNo}_${now.millisecondsSinceEpoch}_$i',
          billNo: bill.billNo,
          billerDate: bill.billerDate,
          customer: bill.customer,
          commodityName: item.itemName,
          englishName: '',
          quantity: item.quantity,
          weightKg: item.weight,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          addedAt: now,
        );
        currentBatches.insert(0, batchEntry);
      }
      await _saveBatches(currentBatches);

      // 2. Aggregate consolidated stock
      for (final item in bill.items) {
        final commodityKey = _normalizeCommodityName(item.itemName);
        final existingIdx = currentStock.indexWhere(
          (inv) => _normalizeCommodityName(inv.commodityName) == commodityKey,
        );

        if (existingIdx != -1) {
          final existing = currentStock[existingIdx];
          final updatedWeight = existing.stockWeightKg + item.weight;
          final updatedRate = item.unitPrice > 0 ? item.unitPrice : existing.lastPurchaseRate;
          final updatedValue = (updatedWeight * updatedRate / 40.0).roundToDouble();

          currentStock[existingIdx] = existing.copyWith(
            stockWeightKg: updatedWeight,
            lastPurchaseRate: updatedRate,
            totalStockValue: updatedValue,
            lastBillerDate: bill.billerDate,
            lastBillNo: bill.billNo,
            lastSupplier: bill.customer,
            lastUpdated: now,
            totalBillsCount: existing.totalBillsCount + 1,
          );
        } else {
          final initialValue = (item.weight * item.unitPrice / 40.0).roundToDouble();
          final newItem = InventoryItem(
            id: 'inv_${commodityKey}_${now.millisecondsSinceEpoch}',
            commodityName: item.itemName,
            englishName: '',
            stockWeightKg: item.weight,
            lastPurchaseRate: item.unitPrice,
            totalStockValue: initialValue,
            lastBillerDate: bill.billerDate,
            lastBillNo: bill.billNo,
            lastSupplier: bill.customer,
            lastUpdated: now,
            totalBillsCount: 1,
          );
          currentStock.add(newItem);
        }
      }

      // Save consolidated stock locally
      final file = File('${dir.path}/$_fileName');
      final jsonString = json.encode(currentStock.map((i) => i.toMap()).toList());
      await file.writeAsString(jsonString, flush: true);

      // Background sync to Python backend & Supabase
      _syncToPythonBackend(bill);
      SupabaseStorageService.syncInventoryToCloud(currentStock);

      debugPrint('[InventoryService] Successfully added bill #${bill.billNo} to inventory.');
      return currentStock;
    } catch (e) {
      debugPrint('[InventoryService] Error adding bill to inventory: $e');
      rethrow;
    }
  }

  /// Generates a styled Excel (.xlsx) spreadsheet for the entire inventory with separate By_Bill_Date sheet
  static Future<File> generateInventoryExcel(
    List<InventoryItem> items, [
    List<InventoryBatchEntry>? batches,
  ]) async {
    final excel = Excel.createExcel();
    const sheetName = 'Inventory_Stock';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headerBg = ExcelColor.fromHexString('#0F766E'); // Teal 700
    final zebraBg = ExcelColor.fromHexString('#F0FDFA');

    // Title Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('غلہ منڈی اسٹاک رجسٹر و انوینٹری (Mandi Stock Register)');

    // Column Headers
    final headers = [
      'نمبر شمار (Sr)',
      'نام جنس (Commodity Name)',
      'موجودہ وزن کلو (Stock kg)',
      'موجودہ وزن من (Stock Maunds)',
      'آخری ریٹ / 40 کلو (Rate Rs/40kg)',
      'کل مالیت (Total Worth Rs)',
      'آخری بل نمبر (Last Bill #)',
      'تاریخ رسید (Biller Date)',
      'بیوپاری / گاہک (Supplier)',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        backgroundColorHex: headerBg,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        fontFamily: getFontFamily(FontFamily.Arial),
      );
    }

    // Data Rows
    double grandTotalWeight = 0;
    double grandTotalValue = 0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rowIdx = i + 3;
      grandTotalWeight += item.stockWeightKg;
      grandTotalValue += item.totalStockValue;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value =
          IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value =
          TextCellValue(item.commodityName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value =
          DoubleCellValue(item.stockWeightKg);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value =
          DoubleCellValue(double.parse(item.stockMaunds.toStringAsFixed(2)));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value =
          DoubleCellValue(item.lastPurchaseRate);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value =
          DoubleCellValue(item.totalStockValue);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value =
          TextCellValue(item.lastBillNo);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value =
          TextCellValue(item.lastBillerDate);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value =
          TextCellValue(item.lastSupplier);

      if (i % 2 == 1) {
        for (int col = 0; col < headers.length; col++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx));
          cell.cellStyle = CellStyle(backgroundColorHex: zebraBg);
        }
      }
    }

    // Grand Totals Row
    final totalRowIdx = items.length + 4;
    final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRowIdx));
    totalCell.value = TextCellValue('کل میزان (Grand Total)');
    totalCell.cellStyle = CellStyle(bold: true);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: totalRowIdx)).value =
        DoubleCellValue(grandTotalWeight);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRowIdx)).value =
        DoubleCellValue(double.parse((grandTotalWeight / 40.0).toStringAsFixed(2)));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRowIdx)).value =
        DoubleCellValue(grandTotalValue);

    // Save Excel file
    // 2. Sheet 2: Separate Inventory Data By Biller Date (تاریخ بل کے مطابق)
    if (batches != null && batches.isNotEmpty) {
      const batchSheetName = 'By_Bill_Date';
      final batchSheet = excel[batchSheetName];
      final batchHeaderBg = ExcelColor.fromHexString('#1E3A8A'); // Blue 900

      batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('تاریخ بل کے مطابق علیحدہ انوینٹری ڈیٹا (Inventory By Bill Date)');

      final batchHeaders = [
        'نمبر شمار (Sr)',
        'تاریخ رسید (Bill Date)',
        'بل نمبر (Bill #)',
        'گاہک / سپلائر (Supplier)',
        'نام جنس (Commodity)',
        'تعداد (Qty)',
        'وزن کلو (Weight kg)',
        'وزن من (Maunds)',
        'ریٹ فی من (Rate Rs/40kg)',
        'کل رقم (Total Rs)',
      ];

      for (int col = 0; col < batchHeaders.length; col++) {
        final cell = batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2));
        cell.value = TextCellValue(batchHeaders[col]);
        cell.cellStyle = CellStyle(
          backgroundColorHex: batchHeaderBg,
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
          fontFamily: getFontFamily(FontFamily.Arial),
        );
      }

      double batchTotalWt = 0;
      double batchTotalVal = 0;

      for (int i = 0; i < batches.length; i++) {
        final b = batches[i];
        final rowIdx = i + 3;
        batchTotalWt += b.weightKg;
        batchTotalVal += b.totalPrice;

        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value =
            IntCellValue(i + 1);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value =
            TextCellValue(b.billerDate);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value =
            TextCellValue(b.billNo);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value =
            TextCellValue(b.customer);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value =
            TextCellValue(b.commodityName);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value =
            DoubleCellValue(b.quantity);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value =
            DoubleCellValue(b.weightKg);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value =
            DoubleCellValue(double.parse(b.maunds.toStringAsFixed(2)));
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value =
            DoubleCellValue(b.unitPrice);
        batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIdx)).value =
            DoubleCellValue(b.totalPrice);

        if (i % 2 == 1) {
          for (int col = 0; col < batchHeaders.length; col++) {
            final cell = batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx));
            cell.cellStyle = CellStyle(backgroundColorHex: zebraBg);
          }
        }
      }

      final bTotalRow = batches.length + 4;
      final bTotalCell = batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: bTotalRow));
      bTotalCell.value = TextCellValue('کل میزان (Total)');
      bTotalCell.cellStyle = CellStyle(bold: true);

      batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: bTotalRow)).value =
          DoubleCellValue(batchTotalWt);
      batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: bTotalRow)).value =
          DoubleCellValue(double.parse((batchTotalWt / 40.0).toStringAsFixed(2)));
      batchSheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: bTotalRow)).value =
          DoubleCellValue(batchTotalVal);
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/inventory_export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  static String _normalizeCommodityName(String name) {
    return name
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .toLowerCase();
  }

  static List<InventoryItem> _getDefaultInitialInventory() {
    return [
      InventoryItem(
        id: 'inv_chana_golden',
        commodityName: 'دال چنا گولڈن',
        englishName: 'Chana Dal Golden',
        stockWeightKg: 125.0,
        lastPurchaseRate: 9900.0,
        totalStockValue: 30938.0,
        lastBillerDate: '19/10/2026',
        lastBillNo: '17405',
        lastSupplier: 'صلاح الدین ساہیوال',
        lastUpdated: DateTime.now(),
        totalBillsCount: 2,
      ),
      InventoryItem(
        id: 'inv_chana_chakwal',
        commodityName: 'چنا چکوال 30 کلو',
        englishName: 'Chakwal Gram',
        stockWeightKg: 90.0,
        lastPurchaseRate: 9600.0,
        totalStockValue: 21600.0,
        lastBillerDate: '19/10/2026',
        lastBillNo: '17405',
        lastSupplier: 'صلاح الدین ساہیوال',
        lastUpdated: DateTime.now(),
        totalBillsCount: 1,
      ),
      InventoryItem(
        id: 'inv_mash_sq',
        commodityName: 'توڑی دال ماش ایس کیو',
        englishName: 'Mash Dal SQ',
        stockWeightKg: 50.0,
        lastPurchaseRate: 17000.0,
        totalStockValue: 21250.0,
        lastBillerDate: '19/10/2026',
        lastBillNo: '17405',
        lastSupplier: 'صلاح الدین ساہیوال',
        lastUpdated: DateTime.now(),
        totalBillsCount: 1,
      ),
    ];
  }

  static List<InventoryBatchEntry> _getDefaultInitialBatches() {
    final now = DateTime.now();
    return [
      InventoryBatchEntry(
        id: 'init_b1',
        billNo: '17405',
        billerDate: '19/10/2026',
        customer: 'صلاح الدین ساہیوال',
        commodityName: 'دال چنا گولڈن',
        weightKg: 25.0,
        unitPrice: 9900.0,
        totalPrice: 6188.0,
        addedAt: now.subtract(const Duration(days: 2)),
      ),
      InventoryBatchEntry(
        id: 'init_b2',
        billNo: '17405',
        billerDate: '19/10/2026',
        customer: 'صلاح الدین ساہیوال',
        commodityName: 'چنا چکوال 30 کلو',
        weightKg: 30.0,
        unitPrice: 9600.0,
        totalPrice: 7200.0,
        addedAt: now.subtract(const Duration(days: 2)),
      ),
      InventoryBatchEntry(
        id: 'init_b3',
        billNo: '17405',
        billerDate: '19/10/2026',
        customer: 'صلاح الدین ساہیوال',
        commodityName: 'توڑی دال ماش ایس کیو',
        weightKg: 25.0,
        unitPrice: 17000.0,
        totalPrice: 10625.0,
        addedAt: now.subtract(const Duration(days: 2)),
      ),
      InventoryBatchEntry(
        id: 'init_b4',
        billNo: '17565',
        billerDate: '27/10/2026',
        customer: 'ملک محمد اسلم',
        commodityName: 'دال چنا گولڈن',
        weightKg: 25.0,
        unitPrice: 9600.0,
        totalPrice: 6000.0,
        addedAt: now.subtract(const Duration(days: 1)),
      ),
      InventoryBatchEntry(
        id: 'init_b5',
        billNo: '17565',
        billerDate: '27/10/2026',
        customer: 'ملک محمد اسلم',
        commodityName: 'چنا چکوال 30 کلو',
        weightKg: 30.0,
        unitPrice: 9400.0,
        totalPrice: 7050.0,
        addedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  static Future<void> _syncToPythonBackend(OcrScanResult bill) async {
    try {
      final url = Uri.parse('http://127.0.0.1:5000/api/add_to_inventory');
      final payload = {
        'bill_no': bill.billNo,
        'biller_date': bill.billerDate,
        'customer': bill.customer,
        'items': bill.items.map((i) => i.toMap()).toList(),
      };
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Offline mode safe
    }
  }
}
