class InventoryBatchEntry {
  final String id;
  final String billNo;
  final String billerDate;
  final String customer;
  final String commodityName;
  final String englishName;
  final double quantity;
  final double weightKg;
  final double unitPrice; // Rate per 40kg (Maund / من)
  final double totalPrice; // Rs
  final DateTime addedAt;

  const InventoryBatchEntry({
    required this.id,
    required this.billNo,
    required this.billerDate,
    required this.customer,
    required this.commodityName,
    this.englishName = '',
    this.quantity = 1.0,
    required this.weightKg,
    required this.unitPrice,
    required this.totalPrice,
    required this.addedAt,
  });

  /// Stock in Pakistani Mandi Maunds (40 kg = 1 Maund / من)
  double get maunds => weightKg / 40.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_no': billNo,
      'biller_date': billerDate,
      'customer': customer,
      'commodity_name': commodityName,
      'english_name': englishName,
      'quantity': quantity,
      'weight_kg': weightKg,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'added_at': addedAt.toIso8601String(),
    };
  }

  factory InventoryBatchEntry.fromMap(Map<String, dynamic> map) {
    return InventoryBatchEntry(
      id: map['id']?.toString() ?? 'batch_${DateTime.now().millisecondsSinceEpoch}',
      billNo: map['bill_no']?.toString() ?? 'N/A',
      billerDate: map['biller_date']?.toString() ?? 'N/A',
      customer: map['customer']?.toString() ?? 'عام گاہک',
      commodityName: map['commodity_name']?.toString() ?? 'نامعلوم',
      englishName: map['english_name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
      addedAt: DateTime.tryParse(map['added_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

