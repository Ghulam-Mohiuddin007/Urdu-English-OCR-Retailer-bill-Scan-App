import 'ocr_bill_item.dart';
import 'ocr_scan_result.dart';

class ScanHistoryEntry {
  final String id;
  final String billNo;
  final String date;
  final String billerDate;
  final String customer;
  final List<OcrBillItem> items;
  final double totalWeight;
  final double subtotal;
  final double commission;
  final double grandTotal;
  final bool addedToInventory;
  final bool syncedToSupabase;
  final String? supabaseId;
  final String? supabaseImageUrl;
  final String? thumbnailPath;
  final String? imagePath;
  final DateTime createdAt;
  final String? rawText;
  final String status; // 'Saved', 'Exported', 'Verified'

  const ScanHistoryEntry({
    required this.id,
    required this.billNo,
    required this.date,
    String? billerDate,
    required this.customer,
    required this.items,
    required this.totalWeight,
    required this.subtotal,
    this.commission = 0.0,
    double? grandTotal,
    this.addedToInventory = false,
    this.syncedToSupabase = false,
    this.supabaseId,
    this.supabaseImageUrl,
    this.thumbnailPath,
    this.imagePath,
    required this.createdAt,
    this.rawText,
    this.status = 'Saved',
  })  : billerDate = billerDate ?? date,
        grandTotal = grandTotal ?? (subtotal + commission);

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
      billerDate: result.billerDate,
      customer: result.customer,
      items: result.items,
      totalWeight: result.totalWeight,
      subtotal: result.subtotal,
      commission: result.commission,
      grandTotal: result.grandTotal,
      addedToInventory: result.addedToInventory,
      syncedToSupabase: result.syncedToSupabase,
      supabaseImageUrl: result.supabaseImageUrl,
      thumbnailPath: thumbnailPath,
      imagePath: fullImagePath ?? result.imagePath,
      createdAt: DateTime.now(),
      rawText: rawText,
      status: 'Saved',
    );
  }

  ScanHistoryEntry copyWith({
    String? id,
    String? billNo,
    String? date,
    String? billerDate,
    String? customer,
    List<OcrBillItem>? items,
    double? totalWeight,
    double? subtotal,
    double? commission,
    double? grandTotal,
    bool? addedToInventory,
    bool? syncedToSupabase,
    String? supabaseId,
    String? supabaseImageUrl,
    String? thumbnailPath,
    String? imagePath,
    DateTime? createdAt,
    String? rawText,
    String? status,
  }) {
    return ScanHistoryEntry(
      id: id ?? this.id,
      billNo: billNo ?? this.billNo,
      date: date ?? this.date,
      billerDate: billerDate ?? this.billerDate,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      totalWeight: totalWeight ?? this.totalWeight,
      subtotal: subtotal ?? this.subtotal,
      commission: commission ?? this.commission,
      grandTotal: grandTotal ?? this.grandTotal,
      addedToInventory: addedToInventory ?? this.addedToInventory,
      syncedToSupabase: syncedToSupabase ?? this.syncedToSupabase,
      supabaseId: supabaseId ?? this.supabaseId,
      supabaseImageUrl: supabaseImageUrl ?? this.supabaseImageUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      rawText: rawText ?? this.rawText,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_no': billNo,
      'date': date,
      'biller_date': billerDate,
      'customer': customer,
      'items': items.map((i) => i.toMap()).toList(),
      'total_weight': totalWeight,
      'subtotal': subtotal,
      'commission': commission,
      'grand_total': grandTotal,
      'added_to_inventory': addedToInventory,
      'synced_to_supabase': syncedToSupabase,
      'supabase_id': supabaseId,
      'supabase_image_url': supabaseImageUrl,
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

    final subtotalVal = (map['subtotal'] as num?)?.toDouble() ?? 0.0;
    final commissionVal = (map['commission'] as num?)?.toDouble() ?? 0.0;
    final grandTotalVal = (map['grand_total'] as num?)?.toDouble() ?? (subtotalVal + commissionVal);
    final dateVal = map['date']?.toString() ?? '';
    final billerDateVal = map['biller_date']?.toString() ?? dateVal;

    return ScanHistoryEntry(
      id: map['id']?.toString() ?? 'scan_${DateTime.now().millisecondsSinceEpoch}',
      billNo: map['bill_no']?.toString() ?? 'N/A',
      date: dateVal,
      billerDate: billerDateVal,
      customer: map['customer']?.toString() ?? '',
      items: items,
      totalWeight: (map['total_weight'] as num?)?.toDouble() ?? 0.0,
      subtotal: subtotalVal,
      commission: commissionVal,
      grandTotal: grandTotalVal,
      addedToInventory: map['added_to_inventory'] == true,
      syncedToSupabase: map['synced_to_supabase'] == true,
      supabaseId: map['supabase_id']?.toString(),
      supabaseImageUrl: map['supabase_image_url']?.toString(),
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
      billerDate: billerDate,
      customer: customer,
      items: items,
      totalWeight: totalWeight,
      subtotal: subtotal,
      commission: commission,
      addedToInventory: addedToInventory,
      syncedToSupabase: syncedToSupabase,
      imagePath: imagePath,
      supabaseImageUrl: supabaseImageUrl,
    );
  }
}
