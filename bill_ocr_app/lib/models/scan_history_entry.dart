import 'ocr_bill_item.dart';
import 'ocr_scan_result.dart';

class ScanHistoryEntry {
  final String id;
  final String billNo;
  final String date;
  final String customer;
  final List<OcrBillItem> items;
  final double totalWeight;
  final double subtotal;
  final String? thumbnailPath;
  final String? imagePath;
  final DateTime createdAt;
  final String? rawText;
  final String status; // 'Saved', 'Exported', 'Verified'

  const ScanHistoryEntry({
    required this.id,
    required this.billNo,
    required this.date,
    required this.customer,
    required this.items,
    required this.totalWeight,
    required this.subtotal,
    this.thumbnailPath,
    this.imagePath,
    required this.createdAt,
    this.rawText,
    this.status = 'Saved',
  });

  factory ScanHistoryEntry.fromScanResult(
    OcrScanResult result, {
    String? thumbnailPath,
    String? fullImagePath,
    String? rawText,
  }) {
    return ScanHistoryEntry(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      billNo: result.billNo,
      date: result.date,
      customer: result.customer,
      items: result.items,
      totalWeight: result.totalWeight,
      subtotal: result.subtotal,
      thumbnailPath: thumbnailPath,
      imagePath: fullImagePath ?? result.imagePath,
      createdAt: DateTime.now(),
      rawText: rawText,
      status: 'Saved',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_no': billNo,
      'date': date,
      'customer': customer,
      'items': items.map((i) => i.toMap()).toList(),
      'total_weight': totalWeight,
      'subtotal': subtotal,
      'thumbnail_path': thumbnailPath,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'raw_text': rawText,
      'status': status,
    };
  }

  factory ScanHistoryEntry.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final items = <OcrBillItem>[];
    for (int i = 0; i < rawItems.length; i++) {
      if (rawItems[i] is Map<String, dynamic>) {
        items.add(OcrBillItem.fromMap(rawItems[i] as Map<String, dynamic>, index: i));
      }
    }

    return ScanHistoryEntry(
      id: map['id']?.toString() ?? 'scan_${DateTime.now().millisecondsSinceEpoch}',
      billNo: map['bill_no']?.toString() ?? 'N/A',
      date: map['date']?.toString() ?? '',
      customer: map['customer']?.toString() ?? '',
      items: items,
      totalWeight: (map['total_weight'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      thumbnailPath: map['thumbnail_path']?.toString(),
      imagePath: map['image_path']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      rawText: map['raw_text']?.toString(),
      status: map['status']?.toString() ?? 'Saved',
    );
  }

  OcrScanResult toScanResult() {
    return OcrScanResult(
      billNo: billNo,
      date: date,
      customer: customer,
      items: items,
      totalWeight: totalWeight,
      subtotal: subtotal,
      imagePath: imagePath,
    );
  }
}

