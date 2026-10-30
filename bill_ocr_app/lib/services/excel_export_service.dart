import 'dart:io';
import 'package:excel/excel.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ocr_scan_result.dart';

class ExcelExportService {
  /// Generates a beautifully styled, formatted .xlsx spreadsheet from the OCR scan result.
  static Future<File> generateExcel({
    required OcrScanResult result,
    String? customFileName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Purchased_Items';

    // Rename default sheet or create
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Modern Emerald Theme Colors
    final headerBgColor = ExcelColor.fromHexString('#0F766E'); // Teal 700
    final headerTextColor = ExcelColor.fromHexString('#FFFFFF');
    final zebraBgColor = ExcelColor.fromHexString('#F8FAFC'); // Slate 50
    final totalBgColor = ExcelColor.fromHexString('#D1FAE5'); // Mint 100
    final totalTextColor = ExcelColor.fromHexString('#065F46'); // Emerald 800

    // Title / Invoice Header Styling
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#0F766E'),
    );

    final metadataStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#475569'),
    );

    // 1. Write Header Title
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('RAASEED BILL SCANNER - رسید برائے خریدار')
      ..cellStyle = titleStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue(
        'Bill No: ${result.billNo}  |  Date: ${result.date}  |  Customer: ${result.customer}',
      )
      ..cellStyle = metadataStyle;

    // 2. Table Headers
    final headers = [
      '#',
      'تفصیل / Item Description',
      'تعداد / Qty',
      'وزن / Weight (kg)',
      'ریٹ / Rate (PKR)',
      'کل رقم / Total (PKR)',
      'تصدیق / Status',
    ];

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: headerBgColor,
      fontColorHex: headerTextColor,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    const startRow = 3;
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: startRow))
        ..value = TextCellValue(headers[col])
        ..cellStyle = headerStyle;
    }

    // 3. Populate Data Rows
    final dataStyle = CellStyle(
      fontSize: 11,
      verticalAlign: VerticalAlign.Center,
    );

    final numStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final verifiedStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#16A34A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    int currentRow = startRow + 1;
    for (int i = 0; i < result.items.length; i++) {
      final item = result.items[i];
      final isEven = i % 2 == 0;
      final rowBg = isEven ? null : zebraBgColor;

      final rowStyle = dataStyle.copyWith(backgroundColorHexVal: rowBg);
      final rowNumStyle = numStyle.copyWith(backgroundColorHexVal: rowBg);

      // Index
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
        ..value = IntCellValue(i + 1)
        ..cellStyle = rowNumStyle;

      // Item Name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
        ..value = TextCellValue(item.itemName)
        ..cellStyle = rowStyle;

      // Quantity
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
        ..value = DoubleCellValue(item.quantity)
        ..cellStyle = rowNumStyle;

      // Weight (kg)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow))
        ..value = DoubleCellValue(item.weight)
        ..cellStyle = rowNumStyle;

      // Unit Price (Rate)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow))
        ..value = DoubleCellValue(item.unitPrice)
        ..cellStyle = rowNumStyle;

      // Line Total
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow))
        ..value = DoubleCellValue(item.totalPrice)
        ..cellStyle = rowNumStyle.copyWith(boldVal: true);

      // Status
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow))
        ..value = TextCellValue(item.status)
        ..cellStyle = verifiedStyle.copyWith(backgroundColorHexVal: rowBg);

      currentRow++;
    }

    // 4. Grand Total Summary Row
    final totalRowStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: totalBgColor,
      fontColorHex: totalTextColor,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
      ..value = TextCellValue('مجموعی میزان / GRAND TOTAL')
      ..cellStyle = totalRowStyle.copyWith(horizontalAlignVal: HorizontalAlign.Center);

    // Sum Quantity
    final totalQty = result.items.fold(0.0, (acc, item) => acc + item.quantity);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
      ..value = DoubleCellValue(totalQty)
      ..cellStyle = totalRowStyle;

    // Sum Weight
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow))
      ..value = DoubleCellValue(result.totalWeight)
      ..cellStyle = totalRowStyle;

    // Blank rate
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow))
      ..value = TextCellValue('-')
      ..cellStyle = totalRowStyle.copyWith(horizontalAlignVal: HorizontalAlign.Center);

    // Sum Total
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow))
      ..value = DoubleCellValue(result.subtotal)
      ..cellStyle = totalRowStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow))
      ..value = TextCellValue('100% Verified')
      ..cellStyle = totalRowStyle.copyWith(horizontalAlignVal: HorizontalAlign.Center);

    // 5. Column Widths
    sheet.setColumnWidth(0, 6.0);
    sheet.setColumnWidth(1, 32.0);
    sheet.setColumnWidth(2, 12.0);
    sheet.setColumnWidth(3, 16.0);
    sheet.setColumnWidth(4, 16.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 14.0);

    // 6. Save to local storage
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file.');
    }

    final directory = await _getSafeStorageDirectory();
    final cleanTimestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = customFileName ?? 'Raaseed_Bill_${result.billNo}_$cleanTimestamp.xlsx';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<Directory> _getSafeStorageDirectory() async {
    try {
      if (Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) return ext;
      }
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      // In test or environments without path_provider channel
      return Directory.systemTemp;
    }
  }

  /// Opens the exported Excel file with device's default spreadsheet app (e.g. Excel, Sheets).
  static Future<OpenResult> openExcelFile(File file) async {
    return await OpenFilex.open(file.path);
  }

  /// Shares the generated .xlsx file directly via system share dialog.
  static Future<ShareResult> shareExcelFile(File file, {String? subject}) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'خریدار کی رسید برائے انوینٹری - Raaseed Bill Export (.xlsx)',
        subject: subject ?? 'Raaseed Bill Export',
      ),
    );
  }
}

