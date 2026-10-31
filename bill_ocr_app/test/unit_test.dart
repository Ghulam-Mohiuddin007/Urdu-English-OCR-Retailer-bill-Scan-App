import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bill_ocr_app/core/utils/text_direction_helper.dart';
import 'package:bill_ocr_app/models/ocr_bill_item.dart';
import 'package:bill_ocr_app/models/ocr_scan_result.dart';
import 'package:bill_ocr_app/models/scan_history_entry.dart';
import 'package:bill_ocr_app/services/scan_history_service.dart';

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

  group('TextDirectionHelper Bilingual Unit Tests', () {
    test('Correctly classifies pure Urdu, English, and mixed scripts', () {
      expect(TextDirectionHelper.detectScript('گندم دیسی'), DetectedScript.urdu);
      expect(TextDirectionHelper.getTextDirection('گندم دیسی'), TextDirection.rtl);

      expect(TextDirectionHelper.detectScript('Wheat Grain Premium'), DetectedScript.english);
      expect(TextDirectionHelper.getTextDirection('Wheat Grain Premium'), TextDirection.ltr);

      expect(TextDirectionHelper.detectScript('دال چنا 25kg'), DetectedScript.mixed);
      expect(TextDirectionHelper.getTextDirection('دال چنا 25kg'), TextDirection.rtl);

      expect(TextDirectionHelper.detectScript('12345'), DetectedScript.numericOnly);
    });
  });

  group('ScanHistoryService & Filtering Tests', () {
    test('Searches by customer, bill number, and Urdu commodities', () {
      final entries = [
        ScanHistoryEntry(
          id: '1',
          billNo: '17405',
          date: '2026-10-29',
          customer: 'صلاح الدین ساہیوال',
          items: const [
            OcrBillItem(
              id: 'i1',
              itemName: 'دال چنا گولڈن',
              quantity: 1,
              weight: 25,
              unitPrice: 9900,
              totalPrice: 6188,
            ),
          ],
          totalWeight: 25,
          subtotal: 6188,
          createdAt: DateTime.now(),
        ),
        ScanHistoryEntry(
          id: '2',
          billNo: '99201',
          date: '2026-10-30',
          customer: 'ملک محمد اسلم',
          items: const [
            OcrBillItem(
              id: 'i2',
              itemName: 'مکئی زرد',
              quantity: 1,
              weight: 40,
              unitPrice: 3200,
              totalPrice: 3200,
            ),
          ],
          totalWeight: 40,
          subtotal: 3200,
          createdAt: DateTime.now(),
        ),
      ];

      // Query customer
      final matchCustomer = ScanHistoryService.filterScans(
        allScans: entries,
        query: 'ساہیوال',
      );
      expect(matchCustomer.length, 1);
      expect(matchCustomer.first.billNo, '17405');

      // Query commodity name in Urdu
      final matchCommodity = ScanHistoryService.filterScans(
        allScans: entries,
        query: 'مکئی',
      );
      expect(matchCommodity.length, 1);
      expect(matchCommodity.first.customer, 'ملک محمد اسلم');

      // Query bill number
      final matchBill = ScanHistoryService.filterScans(
        allScans: entries,
        query: '17405',
      );
      expect(matchBill.length, 1);
    });
  });
}
