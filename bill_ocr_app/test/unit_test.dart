import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bill_ocr_app/core/utils/text_direction_helper.dart';
import 'package:bill_ocr_app/models/inventory_batch_entry.dart';
import 'package:bill_ocr_app/models/inventory_item.dart';
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

    test('OcrScanResult recomputes totals and handles commission & grand total', () {
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
        billerDate: '2026-10-29',
        customer: 'ملک محمد اسلم',
        items: items,
        totalWeight: 0.0,
        subtotal: 0.0,
        commission: 250.0,
      ).recomputeTotals();

      expect(result.totalWeight, 120.0);
      expect(result.subtotal, 14000.0);
      expect(result.commission, 250.0);
      expect(result.grandTotal, 14250.0);
      expect(result.items.length, 2);
      expect(result.parsedBillerDate.year, 2026);
      expect(result.parsedBillerDate.month, 10);
      expect(result.parsedBillerDate.day, 29);
    });

    test('OcrScanResult parses from API response JSON with biller_date and grand_total', () {
      final apiJson = {
        'metadata': {
          'bill_no': 'B-789',
          'biller_date': '2026-10-29',
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
          'subtotal_rs': 5500.0,
          'commission_rs': 100.0,
          'grand_total_rs': 5600.0,
        }
      };

      final parsed = OcrScanResult.fromApiResponse(apiJson, imagePath: '/dummy.jpg');
      expect(parsed.billNo, 'B-789');
      expect(parsed.billerDate, '2026-10-29');
      expect(parsed.customer, 'عمران زرعی سٹور');
      expect(parsed.items.length, 1);
      expect(parsed.items.first.itemName, 'مکئی');
      expect(parsed.items.first.totalPrice, 5500.0);
      expect(parsed.totalWeight, 100.0);
      expect(parsed.subtotal, 5500.0);
      expect(parsed.commission, 100.0);
      expect(parsed.grandTotal, 5600.0);
      expect(parsed.imagePath, '/dummy.jpg');
    });
  });

  group('InventoryItem Model Tests', () {
    test('Calculates Maunds (من) correctly (40 kg = 1 Maund)', () {
      final inv = InventoryItem(
        id: 'inv_1',
        commodityName: 'گندم (Wheat)',
        englishName: 'Wheat',
        stockWeightKg: 160.0,
        lastPurchaseRate: 4000.0,
        totalStockValue: 16000.0,
        lastBillerDate: '2026-10-29',
        lastBillNo: 'BILL-101',
        lastSupplier: 'ملک محمد اسلم',
        lastUpdated: DateTime(2026, 10, 29),
        totalBillsCount: 2,
      );

      expect(inv.stockMaunds, 4.0); // 160 / 40 = 4.0 Maunds
      expect(inv.totalStockValue, 16000.0);

      // Serialization test
      final map = inv.toMap();
      expect(map['commodity_name'], 'گندم (Wheat)');
      expect(map['stock_weight_kg'], 160.0);
      expect(map['last_bill_no'], 'BILL-101');

      final fromMap = InventoryItem.fromMap(map);
      expect(fromMap.commodityName, inv.commodityName);
      expect(fromMap.stockWeightKg, inv.stockWeightKg);
      expect(fromMap.stockMaunds, 4.0);
      expect(fromMap.totalBillsCount, 2);
    });

    test('InventoryBatchEntry stores separate bill date entries and calculates Maunds', () {
      final batch = InventoryBatchEntry(
        id: 'batch_1',
        billNo: '17405',
        billerDate: '19/10/2026',
        customer: 'صلاح الدین ساہیوال',
        commodityName: 'دال چنا گولڈن',
        quantity: 1,
        weightKg: 25.0,
        unitPrice: 9900.0,
        totalPrice: 6188.0,
        addedAt: DateTime(2026, 10, 20),
      );

      expect(batch.billNo, '17405');
      expect(batch.billerDate, '19/10/2026');
      expect(batch.maunds, 25.0 / 40.0);
      expect(batch.totalPrice, 6188.0);

      final map = batch.toMap();
      expect(map['bill_no'], '17405');
      expect(map['biller_date'], '19/10/2026');

      final fromMap = InventoryBatchEntry.fromMap(map);
      expect(fromMap.commodityName, 'دال چنا گولڈن');
      expect(fromMap.billerDate, '19/10/2026');
      expect(fromMap.weightKg, 25.0);
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
          billerDate: '2026-10-29',
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
          grandTotal: 6188,
          createdAt: DateTime.now(),
        ),
        ScanHistoryEntry(
          id: '2',
          billNo: '99201',
          date: '2026-10-30',
          billerDate: '2026-10-30',
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
          grandTotal: 3200,
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

    test('Filters scans by date filter range', () {
      final now = DateTime.now();
      final entries = [
        ScanHistoryEntry(
          id: 'today_scan',
          billNo: '1001',
          date: '2026-11-02',
          billerDate: '2026-11-02',
          customer: 'کشمیر ٹریڈرز',
          items: const [],
          totalWeight: 40,
          subtotal: 3000,
          grandTotal: 3000,
          createdAt: now,
        ),
        ScanHistoryEntry(
          id: 'old_scan',
          billNo: '1002',
          date: '2025-01-01',
          billerDate: '2025-01-01',
          customer: 'قدیم گاہک',
          items: const [],
          totalWeight: 50,
          subtotal: 4000,
          grandTotal: 4000,
          createdAt: DateTime(2025, 1, 1),
        ),
      ];

      final todayScans = ScanHistoryService.filterScans(
        allScans: entries,
        query: '',
        dateFilter: 'Today',
      );
      expect(todayScans.length, 1);
      expect(todayScans.first.id, 'today_scan');

      final allScans = ScanHistoryService.filterScans(
        allScans: entries,
        query: '',
        dateFilter: 'All',
      );
      expect(allScans.length, 2);
    });
  });
}
