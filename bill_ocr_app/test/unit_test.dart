import 'package:flutter_test/flutter_test.dart';
import 'package:bill_ocr_app/models/ocr_bill_item.dart';
import 'package:bill_ocr_app/models/ocr_scan_result.dart';
import 'package:bill_ocr_app/services/excel_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrBillItem & OcrScanResult Model Tests', () {
    test('Correctly stores and calculates Mandi totals', () {
      final item = OcrBillItem(
        id: '1',
        itemName: 'گندم (Wheat)',
        quantity: 3.0,
        weight: 120.0,
        unitPrice: 3800.0,
        totalPrice: 11400.0,
        status: 'Extracted',
      );

      expect(item.itemName, 'گندم (Wheat)');
      expect(item.weight, 120.0);
      expect(item.totalPrice, 11400.0);

      // Test recalculate: 120 kg * 3800 / 40 = 11400
      final recalculated = item.recalculate(isMandiRate: true);
      expect(recalculated.totalPrice, 11400.0);
      expect(recalculated.status, 'Edited');

      final map = item.toMap();
      expect(map['item_name'], 'گندم (Wheat)');
      expect(map['weight'], 120.0);

      final fromMapItem = OcrBillItem.fromMap(map);
      expect(fromMapItem.itemName, 'گندم (Wheat)');
      expect(fromMapItem.weight, 120.0);
      expect(fromMapItem.totalPrice, 11400.0);
    });

    test('OcrScanResult recomputes totals accurately', () {
      final items = [
        const OcrBillItem(
          id: '1',
          itemName: 'گندم (Wheat)',
          quantity: 1.0,
          weight: 40.0,
          unitPrice: 4000.0,
          totalPrice: 4000.0,
        ),
        const OcrBillItem(
          id: '2',
          itemName: 'چاول (Rice)',
          quantity: 2.0,
          weight: 80.0,
          unitPrice: 5000.0,
          totalPrice: 10000.0,
        ),
      ];

      final result = OcrScanResult(
        billNo: 'BILL-101',
        date: '2026-10-29',
        customer: 'ملک محمد اسلم',
        items: items,
        totalWeight: 0.0,
        subtotal: 0.0,
      ).recomputeTotals();

      expect(result.totalWeight, 120.0);
      expect(result.subtotal, 14000.0);
      expect(result.items.length, 2);
    });

    test('OcrScanResult parses from API response JSON', () {
      final apiJson = {
        'metadata': {
          'bill_no': 'B-789',
          'date': '2026-10-29',
          'customer': 'عمران زرعی سٹور',
        },
        'items': [
          {
            'id': 'item-1',
            'commodity': 'مکئی',
            'weight_kg': 100.0,
            'rate': 2200.0,
            'total_price': 5500.0,
          }
        ],
        'summary': {
          'total_weight_kg': 100.0,
          'grand_total_rs': 5500.0,
        }
      };

      final parsed = OcrScanResult.fromApiResponse(apiJson, imagePath: '/dummy.jpg');
      expect(parsed.billNo, 'B-789');
      expect(parsed.customer, 'عمران زرعی سٹور');
      expect(parsed.items.length, 1);
      expect(parsed.items.first.itemName, 'مکئی');
      expect(parsed.items.first.totalPrice, 5500.0);
      expect(parsed.totalWeight, 100.0);
      expect(parsed.subtotal, 5500.0);
      expect(parsed.imagePath, '/dummy.jpg');
    });
  });

  group('ExcelExportService Unit Test', () {
    test('Generates valid Excel spreadsheet byte buffer', () async {
      final items = [
        const OcrBillItem(
          id: '1',
          itemName: 'مکئی (Maize)',
          quantity: 2.0,
          weight: 100.0,
          unitPrice: 2200.0,
          totalPrice: 5500.0,
        ),
      ];

      final result = OcrScanResult(
        billNo: 'INV-TEST-001',
        date: '2026-10-29',
        customer: 'خان زرعی کارپوریشن',
        items: items,
        totalWeight: 100.0,
        subtotal: 5500.0,
      );

      final file = await ExcelExportService.generateExcel(result: result);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(100));

      // Clean up test file
      if (await file.exists()) {
        await file.delete();
      }
    });
  });
}
